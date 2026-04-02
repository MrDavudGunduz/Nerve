import Core
import Foundation
import Testing

@testable import StorageLayer

// MARK: - Module Tests

@Suite("StorageLayer Module Tests")
struct StorageLayerModuleTests {

  @Test("StorageLayer module version is defined")
  func moduleVersion() {
    #expect(!StorageLayer.version.isEmpty)
  }
}

// MARK: - ModelRegistry Regression Tests

/// Regression suite for the empty-ModelRegistry crash risk.
///
/// These tests must fail loudly if a new `@Model` is added to `StorageLayer`
/// but forgotten in ``ModelRegistry/allModels``. The underlying crash
/// (`ModelContainer` receiving a schema with unknown types) would otherwise
/// only appear at runtime on a real device.
@Suite("ModelRegistry Tests")
struct ModelRegistryTests {

  /// Ensures ``ModelRegistry/allModels`` is never empty once `@Model` types exist.
  ///
  /// If this test fails, a new `@Model` was introduced without being registered.
  /// Fix: add the type to `ModelRegistry.allModels`.
  @Test("ModelRegistry.allModels is non-empty")
  func registryIsNonEmpty() {
    #expect(
      !ModelRegistry.allModels.isEmpty,
      "ModelRegistry.allModels must contain at least one @Model type. "
        + "Add your new @Model to ModelRegistry.allModels in ModelRegistry.swift."
    )
  }

  @Test("ModelRegistry contains NewsItemPersistenceModel")
  func registryContainsNewsItem() {
    let typeNames = ModelRegistry.allModels.map { String(describing: $0) }
    #expect(
      typeNames.contains("NewsItemPersistenceModel"),
      "NewsItemPersistenceModel must be registered in ModelRegistry.allModels"
    )
  }
}

// MARK: - NewsItemPersistenceModel Round-Trip Tests

@Suite("NewsItemPersistenceModel Tests")
struct NewsItemPersistenceModelTests {

  private func makeDomainItem(id: String = "news-1") -> NewsItem {
    NewsItem(
      id: id,
      headline: "Test Headline",
      summary: "A test summary",
      source: "TestSource",
      articleURL: URL(string: "https://example.com/article"),
      category: .technology,
      coordinate: GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!,
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      imageURL: URL(string: "https://example.com/image.jpg")
    )
  }

  @Test("NewsItemPersistenceModel round-trips to domain NewsItem without data loss")
  func roundTrip() throws {
    let original = makeDomainItem()
    let persistence = NewsItemPersistenceModel(from: original)
    let restored = try persistence.toDomainModel()

    #expect(restored.id == original.id)
    #expect(restored.headline == original.headline)
    #expect(restored.summary == original.summary)
    #expect(restored.source == original.source)
    #expect(restored.articleURL == original.articleURL)
    #expect(restored.category == original.category)
    #expect(restored.coordinate == original.coordinate)
    #expect(restored.publishedAt == original.publishedAt)
    #expect(restored.imageURL == original.imageURL)
  }

  @Test("NewsItemPersistenceModel stores coordinate components separately")
  func coordinateStoredFlat() {
    let item = makeDomainItem()
    let model = NewsItemPersistenceModel(from: item)

    #expect(model.latitude == item.coordinate.latitude)
    #expect(model.longitude == item.coordinate.longitude)
  }

  @Test("NewsItemPersistenceModel toDomainModel throws on invalid persisted coordinate")
  func invalidCoordinateThrows() throws {
    let item = makeDomainItem()
    let model = NewsItemPersistenceModel(from: item)

    // Simulate data corruption: mutate to an out-of-range latitude.
    model.latitude = 999.0

    #expect(throws: NerveError.self) {
      try model.toDomainModel()
    }
  }

  @Test("NewsItemPersistenceModel toDomainModel throws on unknown category")
  func unknownCategoryThrows() throws {
    let item = makeDomainItem()
    let model = NewsItemPersistenceModel(from: item)

    // Simulate a future category value not present in the current enum.
    model.categoryRaw = "unknown_future_category"

    #expect(throws: NerveError.self) {
      try model.toDomainModel()
    }
  }
}

// MARK: - Protocol Conformance Stub

/// Compile-time verification that `StorageServiceProtocol` can be implemented.
struct StubStorageService: StorageServiceProtocol {

  func saveNews(_ items: [NewsItem]) async throws {}

  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] {
    []
  }

  func deleteNews(id: String) async throws {}

  func pruneExpiredCache() async throws {}
}

// MARK: - DI Round-Trip Tests

@Suite("StorageLayer Protocol Conformance Tests")
struct StorageLayerProtocolTests {

  let container = DependencyContainer()

  @Test("StubStorageService conforms to StorageServiceProtocol and resolves via DI")
  func storageServiceRoundTrip() async throws {
    await container.register(StorageServiceProtocol.self) {
      StubStorageService()
    }

    let service = try await container.resolve(StorageServiceProtocol.self)
    let results = try await service.fetchNews(in: nil, limit: nil, offset: nil)
    #expect(results.isEmpty)
  }

  @Test("StubStorageService save and delete operations complete without error")
  func storageOperations() async throws {
    let service = StubStorageService()
    try await service.saveNews([])
    try await service.deleteNews(id: "test-id")
    try await service.pruneExpiredCache()
  }
}
