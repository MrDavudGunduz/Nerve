//
//  StubTypes.swift
//  MapFeatureTests
//
//  Test doubles (spies, stubs) shared across all MapFeatureTests suites.
//  Each type is an actor or Sendable struct so it is safe to use from
//  concurrent Swift Testing contexts.
//

import Core
import Foundation

@testable import MapFeature

// MARK: - SpyClusterer

/// A test-double ``ClusteringServiceProtocol`` that records the last batch
/// of items it received before forwarding to a real ``AnnotationClusterer``.
///
/// Use this to assert that the view model's filter logic is applied *before*
/// items reach the clustering engine.
actor SpyClusterer: ClusteringServiceProtocol {

  private let injected: [NewsItem]
  private let real = AnnotationClusterer()

  /// The last set of items passed to `cluster(items:in:zoomLevel:)`.
  private(set) var lastItems: [NewsItem] = []

  init(injected: [NewsItem]) {
    self.injected = injected
  }

  func cluster(
    items: [NewsItem], in region: GeoRegion, zoomLevel: Double
  ) async throws -> [NewsCluster] {
    lastItems = items
    return try await real.cluster(items: items, in: region, zoomLevel: zoomLevel)
  }

  func computeMergeRadius(for zoomLevel: Double) async -> Double {
    await real.computeMergeRadius(for: zoomLevel)
  }
}

// MARK: - SpyNewsService

/// A configurable ``NewsServiceProtocol`` stub for unit-testing
/// `MapViewModel.loadNews`.
///
/// Set ``stubbedItems`` to control what `fetchNews(for:)` returns,
/// or set ``stubbedError`` to make it throw.
actor SpyNewsService: NewsServiceProtocol {

  /// Items returned by ``fetchNews(for:)``. Defaults to empty.
  var stubbedItems: [NewsItem] = []

  /// When non-`nil`, ``fetchNews(for:)`` throws this error instead.
  var stubbedError: Error?

  /// Running total of `fetchNews(for:)` invocations.
  private(set) var fetchCallCount: Int = 0

  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] {
    fetchCallCount += 1
    if let error = stubbedError { throw error }
    return stubbedItems
  }

  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(message: "SpyNewsService: fetchNewsDetail not implemented in tests")
  }

  // MARK: Convenience setters (avoids actor-isolation call-site noise in tests)

  func set(items: [NewsItem]) { stubbedItems = items }
  func setError(_ error: Error) { stubbedError = error }
}

// MARK: - SpyStorageService

/// A configurable ``StorageServiceProtocol`` stub for unit-testing
/// `MapViewModel.loadNews`.
///
/// Set ``stubbedCachedItems`` to control what `fetchNews(in:limit:offset:)` returns.
actor SpyStorageService: StorageServiceProtocol {

  /// Items returned by ``fetchNews(in:limit:offset:)``. Defaults to empty.
  var stubbedCachedItems: [NewsItem] = []

  /// Running total of `saveNews(_:)` invocations.
  private(set) var saveCallCount: Int = 0

  /// Items from the most recent `saveNews(_:)` call.
  private(set) var lastSavedItems: [NewsItem] = []

  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] {
    stubbedCachedItems
  }

  func saveNews(_ items: [NewsItem]) async throws {
    saveCallCount += 1
    lastSavedItems = items
  }

  func deleteNews(id: String) async throws {}
  func pruneExpiredCache() async throws {}

  // MARK: Convenience setter

  func set(cached: [NewsItem]) { stubbedCachedItems = cached }
}

// MARK: - StubLocationSvc

/// A minimal ``LocationServiceProtocol`` stub that returns Istanbul coordinates.
///
/// All methods are no-ops unless a test explicitly needs location behaviour.
struct StubLocationSvc: LocationServiceProtocol, Sendable {
  func currentLocation() async throws -> GeoCoordinate? { nil }
  func startTracking() async throws {}
  func stopTracking() async {}
  func requestCurrentLocation() async throws -> GeoCoordinate {
    GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!
  }
}
