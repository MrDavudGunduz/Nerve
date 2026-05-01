//
//  MapViewModelSeedDataTests.swift
//  MapFeatureTests
//
//  Tests for the F-07 fix: verifying that DEBUG seed data is NOT
//  persisted to SwiftData.
//

import Core
import Foundation
import Testing

@testable import MapFeature

// MARK: - MapViewModelSeedDataTests

@Suite("MapViewModel Seed Data Handling")
struct MapViewModelSeedDataTests {

  private let region = TestFixtures.istanbulRegion
  private let zoomLevel: Double = 10

  @Test("Seed data path does not call saveNews on storage service")
  @MainActor
  func seedDataNotPersisted() async {
    // Configure: empty network response AND empty cache → triggers seed path in DEBUG.
    let newsService = SpyNewsService()
    await newsService.set(items: [])
    let storage = SpyStorageService()
    await storage.set(cached: [])

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storage,
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: zoomLevel)

    // In DEBUG builds, seed data should appear on the map but NOT be saved.
    let saveCount = await storage.saveCallCount
    #expect(saveCount == 0, "Seed data must NOT be persisted to storage.")
  }

  @Test("Network data IS persisted when received")
  @MainActor
  func networkDataIsPersisted() async {
    let networkItems = TestFixtures.makeItems(count: 5)

    let newsService = SpyNewsService()
    await newsService.set(items: networkItems)
    let storage = SpyStorageService()
    await storage.set(cached: [])

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storage,
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: zoomLevel)

    // Allow background save task to complete.
    try? await Task.sleep(for: .milliseconds(200))

    let saveCount = await storage.saveCallCount
    #expect(saveCount > 0, "Network data should be persisted to storage.")
  }
}
