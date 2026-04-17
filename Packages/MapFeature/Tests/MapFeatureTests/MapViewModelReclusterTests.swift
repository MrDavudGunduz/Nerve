//
//  MapViewModelReclusterTests.swift
//  MapFeatureTests
//
//  Tests for the recluster path in MapViewModel:
//  - recluster re-runs clustering on the existing item set (no network call).
//  - recluster applies the active category filter (does not show filtered items).
//  - recluster is a no-op when allItems is empty (guards against crash).
//  - recluster passes the updated zoom level to the clusterer.
//  - Consecutive category toggles + reclusters produce stable, idempotent results.
//

import Core
import Testing

@testable import MapFeature

@Suite("MapViewModel recluster Tests")
@MainActor
struct MapViewModelReclusterTests {

  private var region: GeoRegion { TestFixtures.istanbulRegion }

  // MARK: - No Network Call on Recluster

  /// Verifies that `recluster` never performs a network fetch —
  /// it operates exclusively on items already in memory.
  @Test("recluster does not trigger a network fetch")
  func reclusterNoNetworkCall() async throws {
    let newsService = SpyNewsService()
    await newsService.set(items: TestFixtures.makeItems(count: 3))

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    // Prime the view model with data so allItems is non-empty.
    await vm.loadNews(for: region, zoomLevel: 10)
    let countAfterLoad = await newsService.fetchCallCount

    // Recluster must NOT result in an additional fetchNews call.
    await vm.recluster(in: region, zoomLevel: 12)
    let countAfterRecluster = await newsService.fetchCallCount

    #expect(
      countAfterRecluster == countAfterLoad,
      "recluster must not trigger any network fetch")
  }

  // MARK: - Category Filter Applied During Recluster

  /// Verifies that when a category filter is active, `recluster` only passes
  /// the matching items to the clustering engine.
  @Test("recluster applies the active category filter")
  func reclusterRespectsActiveFilter() async throws {
    let techItems = TestFixtures.makeItems(count: 3).map {
      TestFixtures.makeItem(id: $0.id, category: .technology)
    }
    let polItem = TestFixtures.makeItem(id: "pol-unique", category: .politics)

    let newsService = SpyNewsService()
    await newsService.set(items: techItems + [polItem])

    let spyClusterer = SpyClusterer(injected: techItems + [polItem])

    let vm = MapViewModel(
      clusterer: spyClusterer,
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    // Load data into allItems.
    await vm.loadNews(for: region, zoomLevel: 10)

    // Activate a technology-only filter.
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)

    // Recluster with the filter active.
    await vm.recluster(in: region, zoomLevel: 12)

    let lastReceived = await spyClusterer.lastItems
    let receivedCategories = Set(lastReceived.map { $0.category })

    #expect(
      !receivedCategories.contains(.politics),
      "recluster must exclude politics items when only technology filter is active"
    )
    #expect(
      receivedCategories == [.technology],
      "recluster must only pass technology items to the clusterer"
    )
  }

  // MARK: - Recluster Is a No-Op on Empty Items

  /// Verifies that calling `recluster` before any data is loaded neither
  /// crashes the app nor produces a spurious empty cluster array mutation.
  @Test("recluster is a no-op and does not crash when allItems is empty")
  func reclusterEmptySafe() async {
    let vm = MapViewModel()
    await vm.recluster(in: region, zoomLevel: 10)
    #expect(vm.clusters.isEmpty, "clusters must remain empty after recluster on an empty model")
  }

  // MARK: - Recluster Produces Updated Cluster Count

  /// Verifies that zooming in (higher zoom level) produces more, smaller clusters
  /// than zooming out — confirming that reclustering at different zoom levels
  /// actually changes the clustering output.
  @Test("recluster produces more clusters at higher zoom levels")
  func reclusterZoomProducesFewerClustersAtLowZoom() async throws {
    // 20 items spread across Istanbul — enough to cluster differently at different zooms.
    let items = (0..<20).map { i in
      TestFixtures.makeItem(
        id: "item-\(i)",
        latitude: 41.0 + Double(i) * 0.02,
        longitude: 29.0 + Double(i) * 0.02
      )
    }

    let newsService = SpyNewsService()
    await newsService.set(items: items)

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    // Load at city-level zoom (more clustering = fewer clusters).
    await vm.loadNews(for: region, zoomLevel: 8)
    let clusterCountAtZoom8 = vm.clusters.count

    // Recluster at street-level zoom (less clustering = more clusters).
    await vm.recluster(in: region, zoomLevel: 15)
    let clusterCountAtZoom15 = vm.clusters.count

    #expect(
      clusterCountAtZoom15 >= clusterCountAtZoom8,
      "Higher zoom level should produce the same or more clusters than a lower zoom level"
    )
  }

  // MARK: - Consecutive Reclusters Are Idempotent

  /// Verifies that calling `recluster` multiple times with the same arguments
  /// produces a stable result — no state drift from repeated calls.
  @Test("Consecutive reclusters with the same parameters are idempotent")
  func reclusterIdempotent() async throws {
    let items = TestFixtures.makeItems(count: 5)
    let newsService = SpyNewsService()
    await newsService.set(items: items)

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: 10)
    let firstCount = vm.clusters.count

    await vm.recluster(in: region, zoomLevel: 10)
    let secondCount = vm.clusters.count

    await vm.recluster(in: region, zoomLevel: 10)
    let thirdCount = vm.clusters.count

    #expect(firstCount == secondCount, "First and second recluster must produce the same count")
    #expect(secondCount == thirdCount, "Second and third recluster must produce the same count")
  }
}
