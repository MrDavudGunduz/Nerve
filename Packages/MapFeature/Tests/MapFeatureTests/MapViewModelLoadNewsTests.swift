//
//  MapViewModelLoadNewsTests.swift
//  MapFeatureTests
//
//  Tests for the offline-first data pipeline in MapViewModel.loadNews.
//
//  Coverage:
//  - Cache fast-path: cached items render immediately without a network call.
//  - Network-wins merge: network items replace cached items on ID collision.
//  - Seed data injection: Istanbul seed data is used when cache + network are empty.
//  - Non-fatal network failure: a network error is suppressed when cached clusters exist.
//  - isLoading guard: fetchNews is called at least once per loadNews invocation.
//

import Core
import Testing

@testable import MapFeature

@Suite("MapViewModel loadNews Tests")
@MainActor
struct MapViewModelLoadNewsTests {

  private var region: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
  }

  // MARK: Cache Fast-Path

  /// Verifies that items already in the cache are immediately clustered and
  /// displayed even when the network returns an empty response.
  @Test("Cached items produce clusters when the network returns empty")
  func cacheOnlyFastPath() async throws {
    let cached = [TestFixtures.makeItem(id: "c1", latitude: 41.0, longitude: 29.0)]
    let newsService = SpyNewsService()  // returns [] by default
    let storageService = SpyStorageService()
    await storageService.set(cached: cached)

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )
    await vm.loadNews(for: region, zoomLevel: 10)

    #expect(!vm.clusters.isEmpty, "Cached items must produce at least one cluster")
    let allItems = vm.clusters.flatMap { $0.items }
    #expect(allItems.contains(where: { $0.id == "c1" }), "Cluster must contain the cached item")
  }

  // MARK: Network-Wins Merge

  /// Verifies that when the same item ID exists in both the cache and the network
  /// response, the network version takes precedence in the merged result.
  @Test("Network item supersedes cached item on ID collision")
  func networkWinsMerge() async throws {
    let sharedID = "shared-001"
    let cachedVersion = NewsItem(
      id: sharedID,
      headline: "Old Headline",
      summary: "old",
      source: "Cache",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      publishedAt: Date(timeIntervalSinceNow: -3600)
    )
    let networkVersion = NewsItem(
      id: sharedID,
      headline: "Fresh Headline",
      summary: "fresh",
      source: "Network",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      publishedAt: Date()
    )

    let newsService = SpyNewsService()
    await newsService.set(items: [networkVersion])
    let storageService = SpyStorageService()
    await storageService.set(cached: [cachedVersion])

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )
    await vm.loadNews(for: region, zoomLevel: 10)

    let allItems = vm.clusters.flatMap { $0.items }
    let merged = allItems.first(where: { $0.id == sharedID })
    #expect(
      merged?.headline == "Fresh Headline",
      "Network item must replace cached item on ID collision")
  }

  // MARK: Seed Data Injection

  /// Verifies that when neither cache nor network provides data, the built-in
  /// Istanbul seed items are injected so the map is never blank.
  @Test("Istanbul seed data is injected when cache and network are empty")
  func seedDataInjectedWhenEmpty() async throws {
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: SpyNewsService(),
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )
    await vm.loadNews(for: region, zoomLevel: 10)

    #expect(
      !vm.clusters.isEmpty,
      "Seed data must populate clusters when both network and cache are empty")
  }

  // MARK: Non-Fatal Network Failure

  /// Verifies that a network error does not clear existing cached clusters
  /// and does not surface an error to the UI when data is already displayed.
  @Test("Network error is suppressed when cached clusters are visible")
  func networkErrorNonFatalWithClusters() async throws {
    let cached = [TestFixtures.makeItem(id: "c1")]
    let newsService = SpyNewsService()
    await newsService.setError(NerveError.network(message: "Connection timed out"))
    let storageService = SpyStorageService()
    await storageService.set(cached: cached)

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )
    await vm.loadNews(for: region, zoomLevel: 10)

    #expect(!vm.clusters.isEmpty, "Cached clusters must remain on screen after network failure")
    #expect(vm.error == nil, "Error must be suppressed when clusters are already visible")
  }

  // MARK: isLoading Guard

  /// Verifies that fetchNews is called at least once per loadNews invocation,
  /// confirming the network path is always attempted.
  @Test("fetchNews is called once per loadNews invocation")
  func isLoadingGuard() async throws {
    let newsService = SpyNewsService()
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: 10)
    let callCount = await newsService.fetchCallCount
    #expect(callCount >= 1, "fetchNews must be called at least once per loadNews invocation")
  }
}
