//
//  MapViewModelCategoryFilterTests.swift
//  MapFeatureTests
//
//  Tests for MapViewModel's category filter system — toggle semantics,
//  clear/reset, multi-select, and filter propagation to the clusterer.
//

import Core
import Testing

@testable import MapFeature

@Suite("MapViewModel Category Filter Tests")
@MainActor
struct MapViewModelCategoryFilterTests {

  private var region: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
  }

  // MARK: Initial State

  @Test("Initial selectedCategories set is empty")
  func initialCategoriesEmpty() {
    let vm = MapViewModel()
    #expect(vm.selectedCategories.isEmpty)
  }

  // MARK: Toggle Semantics

  @Test("toggleCategory adds a new category to the filter set")
  func toggleAddsCategory() async {
    let vm = MapViewModel()
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    #expect(vm.selectedCategories == [.technology])
  }

  @Test("toggleCategory removes a category that is already selected")
  func toggleRemovesCategory() async {
    let vm = MapViewModel()
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    #expect(vm.selectedCategories.isEmpty)
  }

  @Test("toggleCategory can independently select multiple categories")
  func toggleMultipleCategories() async {
    let vm = MapViewModel()
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    await vm.toggleCategory(.politics, in: region, zoomLevel: 10)
    #expect(vm.selectedCategories.count == 2)
    #expect(vm.selectedCategories.contains(.technology))
    #expect(vm.selectedCategories.contains(.politics))
  }

  // MARK: Clear

  @Test("clearCategoryFilter empties the selection set")
  func clearResetsFilter() async {
    let vm = MapViewModel()
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)
    await vm.toggleCategory(.health, in: region, zoomLevel: 10)
    await vm.clearCategoryFilter(in: region, zoomLevel: 10)
    #expect(vm.selectedCategories.isEmpty)
  }

  @Test("clearCategoryFilter is a no-op when the set is already empty")
  func clearOnEmptyIsNoop() async {
    let vm = MapViewModel()
    await vm.clearCategoryFilter(in: region, zoomLevel: 10)
    #expect(vm.selectedCategories.isEmpty)
  }

  // MARK: Filter Propagation

  @Test("Only items matching the active category reach the clusterer")
  func filteredClustersMatchCategory() async throws {
    let techItem = TestFixtures.makeItem(id: "tech-1", category: .technology)
    let polItem = TestFixtures.makeItem(id: "pol-1", category: .politics)

    // Wire up a real load path so allItems is populated before the filter test.
    let newsService = SpyNewsService()
    await newsService.set(items: [techItem, polItem])

    // SpyClusterer records the exact items passed to it.
    let spyClusterer = SpyClusterer(injected: [techItem, polItem])
    let vm = MapViewModel(
      clusterer: spyClusterer,
      newsService: newsService,
      storageService: SpyStorageService(),
      locationService: StubLocationSvc()
    )

    // Prime allItems — without this the ViewModel's internal collection is empty.
    await vm.loadNews(for: region, zoomLevel: 10)

    // Now activate the technology filter and recluster.
    await vm.toggleCategory(.technology, in: region, zoomLevel: 10)

    let lastReceived = await spyClusterer.lastItems
    let receivedCategories = Set(lastReceived.map { $0.category })
    #expect(
      receivedCategories == [.technology],
      "Only technology items should reach the clusterer after filter")
  }
}
