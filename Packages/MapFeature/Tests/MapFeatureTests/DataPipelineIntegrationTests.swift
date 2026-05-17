//
//  DataPipelineIntegrationTests.swift
//  MapFeatureTests
//
//  Created by Davud Gunduz on 14.05.2026.
//

import Core
import Foundation
@testable import MapFeature
import Testing

/// Integration tests that verify the full data pipeline:
/// Network → Storage → ViewModel → Clustering → UI state.
///
/// Unlike unit tests that mock individual layers, these tests wire up
/// in-memory implementations to validate end-to-end data flow.
@Suite("Data Pipeline Integration Tests")
@MainActor
struct DataPipelineIntegrationTests {

  // MARK: - Helpers

  /// An in-memory storage service that stores items in a dictionary.
  private final class InMemoryStorageService: StorageServiceProtocol, @unchecked Sendable {
    private var items: [String: NewsItem] = [:]

    func saveNews(_ items: [NewsItem]) async throws {
      for item in items { self.items[item.id] = item }
    }

    func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] {
      Array(items.values)
    }

    func deleteNews(id: String) async throws {
      items.removeValue(forKey: id)
    }

    func pruneExpiredCache() async throws {}
  }

  /// A news service that returns a fixed set of items.
  private struct FixedNewsService: NewsServiceProtocol {
    let items: [NewsItem]

    func fetchNews(for region: GeoRegion) async throws -> [NewsItem] { items }
    func fetchNewsDetail(id: String) async throws -> NewsItem {
      guard let item = items.first(where: { $0.id == id }) else {
        throw NerveError.network(message: "Not found", reason: .notFound)
      }
      return item
    }
  }

  /// A no-op location service.
  private struct NullLocationService: LocationServiceProtocol {
    func startTracking() async throws {}
    func stopTracking() async {}
    func currentLocation() async throws -> GeoCoordinate? { nil }
    func requestCurrentLocation() async throws -> GeoCoordinate {
      throw NerveError.location(message: "Not available in tests.")
    }
  }

  /// Creates test news items spread across Istanbul.
  private func makeTestItems(count: Int = 10) -> [NewsItem] {
    (0..<count).compactMap { i in
      guard let coord = GeoCoordinate(
        latitude: 41.0 + Double(i) * 0.01,
        longitude: 29.0 + Double(i) * 0.01
      ) else { return nil }
      return NewsItem(
        id: "int-\(i)",
        headline: "Integration Test Item \(i)",
        summary: "Summary \(i)",
        source: "IntegrationTest",
        category: .technology,
        coordinate: coord,
        publishedAt: Date()
      )
    }
  }

  private var testRegion: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 100_000
    )!
  }

  // MARK: - Tests

  @Test("loadNews populates clusters from network items")
  func loadNewsPopulatesClusters() async {
    let items = makeTestItems(count: 10)
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: items),
      storageService: InMemoryStorageService(),
      locationService: NullLocationService()
    )

    await vm.loadNews(for: testRegion, zoomLevel: 12.0)

    #expect(!vm.clusters.isEmpty, "Clusters should be populated after load")
    // Total items across all clusters must equal input count.
    let totalItems = vm.clusters.reduce(0) { $0 + $1.count }
    #expect(totalItems == 10, "All 10 items should appear in clusters")
  }

  @Test("loadNews persists items to storage and serves from cache")
  func loadNewsPersistsAndServesFromCache() async {
    let items = makeTestItems(count: 5)
    let storage = InMemoryStorageService()
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: items),
      storageService: storage,
      locationService: NullLocationService()
    )

    // First load — network + persist.
    await vm.loadNews(for: testRegion, zoomLevel: 10.0)
    #expect(!vm.clusters.isEmpty)

    // Wait for the background save task to complete — `scheduleSave` dispatches
    // persistence as a background `Task`, so without awaiting, the assertion
    // below races against the save.
    await vm.saveTask?.value

    // Verify persistence.
    let persisted = try? await storage.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(persisted?.count == 5, "All items should be persisted")
  }

  @Test("Category filter reduces displayed clusters")
  func categoryFilterReducesClusters() async {
    // Mix of technology and science items.
    var items = makeTestItems(count: 6)
    items = items.enumerated().map { index, item in
      NewsItem(
        id: item.id,
        headline: item.headline,
        summary: item.summary,
        source: item.source,
        category: index < 3 ? .technology : .science,
        coordinate: item.coordinate,
        publishedAt: item.publishedAt
      )
    }

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: items),
      storageService: InMemoryStorageService(),
      locationService: NullLocationService()
    )

    await vm.loadNews(for: testRegion, zoomLevel: 12.0)
    let allClusterItemCount = vm.clusters.reduce(0) { $0 + $1.count }
    #expect(allClusterItemCount == 6)

    // Filter to technology only.
    await vm.toggleCategory(.technology, in: testRegion, zoomLevel: 12.0)
    let filteredCount = vm.clusters.reduce(0) { $0 + $1.count }
    #expect(filteredCount == 3, "Only technology items should remain")
  }

  @Test("reset() clears all state and cancels tasks")
  func resetClearsState() async {
    let items = makeTestItems(count: 5)
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: items),
      storageService: InMemoryStorageService(),
      locationService: NullLocationService()
    )

    await vm.loadNews(for: testRegion, zoomLevel: 10.0)
    #expect(!vm.clusters.isEmpty)

    vm.reset()

    #expect(vm.clusters.isEmpty, "Clusters should be empty after reset")
    #expect(vm.allItems.isEmpty, "allItems should be empty after reset")
    #expect(vm.error == nil, "Error should be nil after reset")
    #expect(!vm.isLoading, "isLoading should be false after reset")
  }

  @Test("Empty network response with empty cache shows no error")
  func emptyResponseNoError() async {
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: []),
      storageService: InMemoryStorageService(),
      locationService: NullLocationService()
    )

    await vm.loadNews(for: testRegion, zoomLevel: 10.0)

    // In release mode, empty response should not set an error.
    #if !DEBUG
      #expect(vm.error == nil, "Empty response should not produce an error")
    #endif
    #expect(!vm.isLoading, "Loading should complete")
  }

  @Test("Memory cap trims items beyond maxItemsCapacity")
  func memoryCapTrims() async {
    // Generate more items than the cap.
    let items = makeTestItems(count: MapViewModel.maxItemsCapacity + 50)
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: FixedNewsService(items: items),
      storageService: InMemoryStorageService(),
      locationService: NullLocationService()
    )

    await vm.loadNews(for: testRegion, zoomLevel: 8.0)

    #expect(
      vm.allItems.count <= MapViewModel.maxItemsCapacity,
      "allItems should be trimmed to maxItemsCapacity (\(MapViewModel.maxItemsCapacity))"
    )
  }
}
