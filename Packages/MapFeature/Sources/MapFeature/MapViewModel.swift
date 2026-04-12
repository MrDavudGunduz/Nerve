//
//  MapViewModel.swift
//  MapFeature
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation
import OSLog
import Observation

// MARK: - MapViewModel

/// Observable view model that drives ``NerveMapView`` with an offline-first
/// data pipeline.
///
/// ## Data Flow
///
/// ```
/// 1. loadNews(for: region)
///    ├── [FAST PATH] fetch cached items → cluster → update UI immediately
///    └── [NETWORK]   fetch from NewsService concurrently
///                     ├── success → persist + merge → re-cluster → update UI
///                     └── failure → log warning, keep cached data displayed
/// ```
///
/// This pattern ensures the map is never blank: cached data is shown within
/// milliseconds while fresh data loads in the background.
///
/// ## Threading
///
/// - All `@Observable` state mutations happen on `@MainActor`.
/// - Clustering runs on `AnnotationClusterer`'s actor (off main thread).
/// - Storage and network calls are awaited without blocking the main thread.
@Observable
public final class MapViewModel: @unchecked Sendable {

  // MARK: - Published State

  /// The current set of spatial clusters rendered on the map.
  public private(set) var clusters: [NewsCluster] = []

  /// Whether a data load or clustering pass is in progress.
  public private(set) var isLoading: Bool = false

  /// The last error encountered. Displayed as a dismissable banner.
  public private(set) var error: NerveError?

  /// The user's current location (if available). Used to center the map.
  public private(set) var userLocation: GeoCoordinate?

  // MARK: - Private State

  /// All items currently in memory (cached + fetched this session).
  private var allItems: [NewsItem] = []

  /// The last region successfully loaded for — used for deduplication.
  private var lastRegion: GeoRegion?

  private let logger = Logger(subsystem: "com.davudgunduz.Nerve", category: "MapViewModel")

  // MARK: - Dependencies

  private let clusterer: any ClusteringServiceProtocol
  private let newsService: any NewsServiceProtocol
  private let storageService: any StorageServiceProtocol
  private let locationService: any LocationServiceProtocol

  // MARK: - Init

  /// Creates a fully-wired view model for production use.
  public init(
    clusterer: any ClusteringServiceProtocol,
    newsService: any NewsServiceProtocol,
    storageService: any StorageServiceProtocol,
    locationService: any LocationServiceProtocol
  ) {
    self.clusterer = clusterer
    self.newsService = newsService
    self.storageService = storageService
    self.locationService = locationService
  }

  /// Convenience init with explicit clusterer — used in tests and previews
  /// where the caller only needs to override clustering behavior.
  public init(clusterer: any ClusteringServiceProtocol = AnnotationClusterer()) {
    self.clusterer = clusterer
    self.newsService = StubNewsServiceInternal()
    self.storageService = StubStorageServiceInternal()
    self.locationService = StubLocationServiceInternal()
  }

  // MARK: - Public API

  /// Starts user location tracking and centers the map on the first fix.
  @MainActor
  public func startLocationTracking() async {
    do {
      try await locationService.startTracking()
      if let coord = try await locationService.currentLocation() {
        userLocation = coord
      }
    } catch {
      logger.warning("Location unavailable: \(error.localizedDescription)")
      // Non-fatal — map defaults to Istanbul center.
    }
  }

  /// Loads news items for the given region using the offline-first strategy.
  ///
  /// 1. Serves cached data immediately.
  /// 2. Concurrently fetches fresh data from the network.
  /// 3. Merges, persists, and re-clusters on success.
  ///
  /// - Parameters:
  ///   - region: The visible map region to load data for.
  ///   - zoomLevel: Current zoom level for clustering granularity.
  @MainActor
  public func loadNews(for region: GeoRegion, zoomLevel: Double) async {
    guard !isLoading else { return }
    isLoading = true
    error = nil
    lastRegion = region

    do {
      // ── FAST PATH: serve from cache ──
      let cached = (try? await storageService.fetchNews(in: region, limit: 200, offset: nil)) ?? []
      if !cached.isEmpty {
        logger.debug("Cache hit: \(cached.count) items")
        await updateClusters(with: cached, in: region, zoomLevel: zoomLevel)
      }

      // ── NETWORK PATH (runs concurrently with cache display) ──
      let fetched = try await newsService.fetchNews(for: region)

      if !fetched.isEmpty {
        logger.info("Network: \(fetched.count) items received")
        // Persist in background — don't block clustering.
        Task.detached(priority: .background) { [weak self] in
          try? await self?.storageService.saveNews(fetched)
        }

        // Merge: network items take precedence over identical cached items.
        let allByID = Dictionary(
          (cached + fetched).map { ($0.id, $0) },
          uniquingKeysWith: { _, network in network }
        )
        let merged = Array(allByID.values)
        allItems = merged
        await updateClusters(with: merged, in: region, zoomLevel: zoomLevel)
      } else if cached.isEmpty {
        // Nothing from cache or network — inject seed data.
        logger.info("Empty data — loading seed data for development.")
        let seed = SeedData.istanbulItems
        Task.detached(priority: .background) { [weak self] in
          try? await self?.storageService.saveNews(seed)
        }
        allItems = seed
        await updateClusters(with: seed, in: region, zoomLevel: zoomLevel)
      }

    } catch let nerveError as NerveError {
      // Network failure is non-fatal if we already have cached data.
      if clusters.isEmpty {
        self.error = nerveError
      }
      logger.warning("Network fetch failed: \(nerveError.errorDescription ?? "unknown")")
    } catch {
      logger.error("Unexpected error in loadNews: \(error.localizedDescription)")
    }

    isLoading = false
  }

  /// Re-clusters the current item set for a new zoom level without fetching.
  ///
  /// Called when the user pans/zooms without a significant region change.
  @MainActor
  public func recluster(in region: GeoRegion, zoomLevel: Double) async {
    guard !allItems.isEmpty else { return }
    await updateClusters(with: allItems, in: region, zoomLevel: zoomLevel)
  }

  /// Clears all clusters, items, and error state.
  @MainActor
  public func reset() {
    clusters = []
    allItems = []
    error = nil
    isLoading = false
    lastRegion = nil
  }

  // MARK: - Private

  @MainActor
  private func updateClusters(
    with items: [NewsItem],
    in region: GeoRegion,
    zoomLevel: Double
  ) async {
    do {
      let result = try await clusterer.cluster(items: items, in: region, zoomLevel: zoomLevel)
      clusters = result
      logger.debug("Clustered \(items.count) items → \(result.count) clusters")
    } catch {
      logger.error("Clustering failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Internal Stubs (Preview / Test use only)

private struct StubNewsServiceInternal: NewsServiceProtocol, Sendable {
  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] { [] }
  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(message: "StubNewsServiceInternal")
  }
}

private struct StubStorageServiceInternal: StorageServiceProtocol, Sendable {
  func saveNews(_ items: [NewsItem]) async throws {}
  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] { [] }
  func deleteNews(id: String) async throws {}
  func pruneExpiredCache() async throws {}
}

private struct StubLocationServiceInternal: LocationServiceProtocol, Sendable {
  func currentLocation() async throws -> GeoCoordinate? { nil }
  func startTracking() async throws {}
  func stopTracking() async {}
  func requestCurrentLocation() async throws -> GeoCoordinate {
    GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!
  }
}
