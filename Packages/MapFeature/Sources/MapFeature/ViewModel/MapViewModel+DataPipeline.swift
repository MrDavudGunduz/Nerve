//
//  MapViewModel+DataPipeline.swift
//  MapFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation

// MARK: - MapViewModel + Data Pipeline

/// Extension containing the offline-first data loading pipeline.
///
/// ## Responsibilities
///
/// - ``loadNews(for:zoomLevel:)`` — cache-first, network-second loading
/// - ``recluster(in:zoomLevel:)`` — re-clustering without a network round-trip
/// - ``reset()`` — full state teardown with Task cancellation
/// - ``startLocationTracking()`` — user location acquisition
///
/// ## Data Flow
///
/// ```
/// loadNews(for: region)
///    ├── [FAST PATH] fetch cached items → cluster → update UI immediately
///    └── [NETWORK]   fetch from NewsService concurrently
///                     ├── success → persist + merge → re-cluster → update UI
///                     └── failure → log warning, keep cached data displayed
/// ```
extension MapViewModel {

  // MARK: - Location

  /// Starts user location tracking and centers the map on the first fix.
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

  // MARK: - Load News

  /// Loads news items for the given region using the offline-first strategy.
  ///
  /// 1. Serves cached data immediately.
  /// 2. Concurrently fetches fresh data from the network.
  /// 3. Merges, persists, and re-clusters on success.
  ///
  /// - Parameters:
  ///   - region: The visible map region to load data for.
  ///   - zoomLevel: Current zoom level for clustering granularity.
  public func loadNews(for region: GeoRegion, zoomLevel: Double) async {
    // Cancel any in-flight load — the newest call always wins.
    loadTask?.cancel()

    let task = Task { @MainActor [weak self] in
      guard let self, !Task.isCancelled else { return }
      isLoading = true
      error = nil
      lastRegion = region

      do {
        // ── FAST PATH: serve from cache ──
        let cached =
          (try? await storageService.fetchNews(in: region, limit: 200, offset: nil)) ?? []
        guard !Task.isCancelled else { return }
        if !cached.isEmpty {
          logger.debug("Cache hit: \(cached.count) items")
          await updateClusters(with: cached, in: region, zoomLevel: zoomLevel)
        }

        // ── NETWORK PATH (runs concurrently with cache display) ──
        let fetched = try await newsService.fetchNews(for: region)
        guard !Task.isCancelled else { return }

        if !fetched.isEmpty {
          logger.info("Network: \(fetched.count) items received")

          // Merge: network items take precedence over identical cached items.
          let allByID = Dictionary(
            (cached + fetched).map { ($0.id, $0) },
            uniquingKeysWith: { _, network in network }
          )
          let merged = Array(allByID.values)
          allItems = merged
          trimOldestItems()
          await updateClusters(with: filteredItems, in: region, zoomLevel: zoomLevel)

          // Persist after clustering — cancel any superseded save.
          scheduleSave(allItems)

          // Enqueue background AI analysis for un-analyzed items.
          scheduleAnalysis(allItems, in: region, zoomLevel: zoomLevel)
        } else if cached.isEmpty {
          #if DEBUG
            // Seed data injected ONLY in debug builds for development.
            // Intentionally NOT persisted — seed data stays in-memory only
            // to prevent stale demo data from leaking into production
            // SwiftData stores across build configurations.
            logger.info("Empty data — loading seed data for development (in-memory only).")
            let seed = SeedData.istanbulItems
            allItems = seed
            await updateClusters(with: seed, in: region, zoomLevel: zoomLevel)

            // Analyze seed items for immediate credibility badges.
            scheduleAnalysis(seed, in: region, zoomLevel: zoomLevel)
          #else
            logger.info("No data available for this region.")
          #endif
        }

      } catch let nerveError as NerveError {
        // Network failure is non-fatal if we already have cached data.
        if clusters.isEmpty {
          self.error = nerveError
        }
        logger.warning("Network fetch failed: \(nerveError.debugDescription)")
      } catch {
        if !Task.isCancelled {
          logger.error("Unexpected error in loadNews: \(error.localizedDescription)")
        }
      }

      isLoading = false
    }
    loadTask = task
    await task.value
  }

  // MARK: - Recluster

  /// Re-clusters the current item set for a new zoom level without fetching.
  ///
  /// Called when the user pans/zooms without a significant region change.
  public func recluster(in region: GeoRegion, zoomLevel: Double) async {
    guard !allItems.isEmpty else { return }
    await updateClusters(with: filteredItems, in: region, zoomLevel: zoomLevel)
  }

  // MARK: - Reset

  /// Clears all clusters, items, and error state.
  ///
  /// Cancels any in-flight background save before clearing state so that
  /// a stale batch cannot be written after the view model has been reset.
  public func reset() {
    loadTask?.cancel()
    loadTask = nil
    saveTask?.cancel()
    saveTask = nil
    analyzeTask?.cancel()
    analyzeTask = nil
    clusters = []
    allItems = []
    error = nil
    isLoading = false
    lastRegion = nil
  }
}
