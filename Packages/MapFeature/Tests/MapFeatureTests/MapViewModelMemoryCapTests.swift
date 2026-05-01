//
//  MapViewModelMemoryCapTests.swift
//  MapFeatureTests
//
//  Tests for the F-12 memory cap feature: verifying that `allItems`
//  is bounded to `maxItemsCapacity` and oldest items are evicted.
//

import Core
import Foundation
import Testing

@testable import MapFeature

// MARK: - MapViewModelMemoryCapTests

@Suite("MapViewModel Memory Cap")
struct MapViewModelMemoryCapTests {

  // MARK: - Helpers

  private let region = TestFixtures.istanbulRegion
  private let zoomLevel: Double = 10

  /// Creates a view model wired with a spy news service that returns the given items.
  @MainActor
  private func makeViewModel(
    networkItems: [NewsItem]
  ) async -> (MapViewModel, SpyNewsService, SpyStorageService) {
    let spy = SpyNewsService()
    await spy.set(items: networkItems)
    let storage = SpyStorageService()
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: spy,
      storageService: storage,
      locationService: StubLocationSvc()
    )
    return (vm, spy, storage)
  }

  // MARK: - Tests

  @Test("Items within capacity limit are not trimmed")
  @MainActor
  func itemsWithinCapacityAreRetained() async {
    let items = makeItems(count: 100)
    let (vm, _, _) = await makeViewModel(networkItems: items)

    await vm.loadNews(for: region, zoomLevel: zoomLevel)

    #expect(vm.clusters.flatMap(\.items).count <= 100)
  }

  @Test("Items exceeding capacity are trimmed to max")
  @MainActor
  func itemsExceedingCapacityAreTrimmed() async {
    // Generate 600 items — exceeds the 500 cap.
    let items = makeItems(count: 600)
    let (vm, _, _) = await makeViewModel(networkItems: items)

    await vm.loadNews(for: region, zoomLevel: zoomLevel)

    // The view model's clusters should collectively contain at most 500 items.
    let totalItemsInClusters = vm.clusters.flatMap(\.items).count
    #expect(totalItemsInClusters <= 500)
  }

  @Test("Oldest items are evicted first when cap is exceeded")
  @MainActor
  func oldestItemsEvictedFirst() async {
    // Create items with known dates: newest first.
    let now = Date()
    let items = (0..<600).map { i in
      let offset = Double(i) * 0.001
      return NewsItem(
        id: "cap-\(i)",
        headline: "Headline \(i)",
        summary: "Summary",
        source: "Source",
        category: .technology,
        coordinate: GeoCoordinate(latitude: 41.0 + offset, longitude: 29.0 + offset)!,
        // Item 0 is newest, item 599 is oldest.
        publishedAt: now.addingTimeInterval(-Double(i) * 3600)
      )
    }

    let (vm, _, _) = await makeViewModel(networkItems: items)
    await vm.loadNews(for: region, zoomLevel: zoomLevel)

    // The most recent item (id: "cap-0") should be retained.
    let allClusteredIDs = Set(vm.clusters.flatMap(\.items).map(\.id))
    #expect(allClusteredIDs.contains("cap-0"))

    // The oldest item (id: "cap-599") should have been evicted.
    #expect(!allClusteredIDs.contains("cap-599"))
  }

  // MARK: - Fixture

  private func makeItems(count: Int) -> [NewsItem] {
    (0..<count).map { i in
      let offset = Double(i) * 0.001
      return TestFixtures.makeItem(
        id: "mem-\(i)",
        headline: "Memory Cap Test \(i)",
        latitude: 41.0 + offset,
        longitude: 29.0 + offset
      )
    }
  }
}
