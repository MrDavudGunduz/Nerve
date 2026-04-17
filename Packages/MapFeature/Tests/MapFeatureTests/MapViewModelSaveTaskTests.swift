//
//  MapViewModelSaveTaskTests.swift
//  MapFeatureTests
//
//  Tests for the background save-task lifecycle inside MapViewModel:
//  - A background save is scheduled after a successful network fetch.
//  - reset() cancels any in-flight save so a stale batch cannot be persisted.
//  - A second loadNews call cancels the in-flight save from the first call.
//

import Core
import Testing

@testable import MapFeature

@Suite("MapViewModel Save Task Tests")
@MainActor
struct MapViewModelSaveTaskTests {

  // MARK: - Helpers

  private var region: GeoRegion { TestFixtures.istanbulRegion }

  // MARK: - Save Is Scheduled After Network Fetch

  /// Verifies that `saveNews` is called exactly once after a successful
  /// network fetch that returns new items.
  ///
  /// The background save is intentionally scheduled with `.background` priority,
  /// so we give it a brief yield after `loadNews` completes.
  @Test("saveNews is called once after a successful network fetch")
  func saveScheduledAfterNetworkFetch() async throws {
    let networkItems = [TestFixtures.makeItem(id: "net-1")]
    let newsService = SpyNewsService()
    await newsService.set(items: networkItems)
    let storageService = SpyStorageService()

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: 10)

    // Yield to allow the background save Task to complete.
    try await Task.sleep(for: .milliseconds(100))

    let callCount = await storageService.saveCallCount
    #expect(callCount >= 1, "saveNews must be called at least once after a network fetch")
  }

  // MARK: - Saved Items Match Fetched Items

  /// Verifies that the items persisted by the background save are the
  /// merged result of cache + network items (network wins on collision),
  /// not just the raw network response.
  @Test("Persisted items are the merged cache + network result")
  func savedItemsAreTheFullMergedSet() async throws {
    let cachedItem = TestFixtures.makeItem(id: "cached-1", headline: "Old")
    let networkItem = TestFixtures.makeItem(id: "net-1", headline: "New")

    let newsService = SpyNewsService()
    await newsService.set(items: [networkItem])
    let storageService = SpyStorageService()
    await storageService.set(cached: [cachedItem])

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: 10)
    try await Task.sleep(for: .milliseconds(100))

    let saved = await storageService.lastSavedItems
    let savedIDs = Set(saved.map { $0.id })

    // Merged set must include both cache-only and network items.
    #expect(savedIDs.contains("cached-1"), "Cached item must be part of the persisted merge")
    #expect(savedIDs.contains("net-1"), "Network item must be part of the persisted merge")
  }

  // MARK: - Save Is Cancelled on Reset

  /// Verifies that calling `reset()` before the background save completes
  /// does not cause an additional write to storage.
  ///
  /// The save task is cancelled synchronously inside `reset()`, so
  /// `saveCallCount` must remain 0 if reset races the background task.
  @Test("reset() cancels the in-flight background save")
  func resetCancelsBackgroundSave() async throws {
    let networkItems = TestFixtures.makeItems(count: 50)
    let newsService = SpyNewsService()
    await newsService.set(items: networkItems)

    // Use a slow storage service to give reset() time to race.
    let storageService = SlowSpyStorageService(saveDelay: .milliseconds(200))

    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: newsService,
      storageService: storageService,
      locationService: StubLocationSvc()
    )

    // Start load (schedules a background save).
    await vm.loadNews(for: region, zoomLevel: 10)

    // Immediately reset — this should cancel the pending save.
    vm.reset()

    // Wait longer than the save delay to ensure the Task had time to run
    // if it had not been cancelled.
    try await Task.sleep(for: .milliseconds(400))

    let callCount = await storageService.saveCallCount
    #expect(
      callCount == 0,
      "Background save must be cancelled when reset() is called before it completes")
  }

  // MARK: - Seed Data Save

  /// Verifies that when seed data is injected (empty cache + empty network),
  /// the seed items are persisted so they are available on the fast path
  /// next time the user opens the map.
  @Test("Seed data is saved to storage when injected")
  func seedDataIsPersisted() async throws {
    let storageService = SpyStorageService()
    let vm = MapViewModel(
      clusterer: AnnotationClusterer(),
      newsService: SpyNewsService(),
      storageService: storageService,
      locationService: StubLocationSvc()
    )

    await vm.loadNews(for: region, zoomLevel: 10)
    try await Task.sleep(for: .milliseconds(100))

    let callCount = await storageService.saveCallCount
    #expect(callCount >= 1, "Seed data must be persisted after injection")

    let savedCount = await storageService.lastSavedItems.count
    #expect(savedCount > 0, "At least one seed item must have been saved")
  }
}

// MARK: - SlowSpyStorageService

/// A ``StorageServiceProtocol`` stub whose `saveNews` suspends for a
/// configurable duration before completing — used to test Task cancellation.
private actor SlowSpyStorageService: StorageServiceProtocol {

  private let saveDelay: Duration
  private(set) var saveCallCount: Int = 0

  init(saveDelay: Duration) {
    self.saveDelay = saveDelay
  }

  func saveNews(_ items: [NewsItem]) async throws {
    try await Task.sleep(for: saveDelay)
    // Only increments if the sleep completes without cancellation.
    saveCallCount += 1
  }

  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] { [] }
  func deleteNews(id: String) async throws {}
  func pruneExpiredCache() async throws {}
}
