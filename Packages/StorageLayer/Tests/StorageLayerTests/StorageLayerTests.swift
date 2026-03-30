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

// MARK: - Protocol Conformance Stub

/// Compile-time verification that `StorageServiceProtocol` can be implemented.
struct StubStorageService: StorageServiceProtocol {

  func saveNews(_ items: [NewsItem]) async throws {}

  func fetchNews(in region: GeoRegion?) async throws -> [NewsItem] {
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
    let results = try await service.fetchNews(in: nil)
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
