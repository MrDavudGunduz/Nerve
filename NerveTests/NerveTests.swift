//
//  NerveTests.swift
//  NerveTests
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core
import StorageLayer
import Testing

// MARK: - Nerve App Smoke Tests

/// App-level smoke tests.
///
/// These tests verify high-level invariants that cannot be tested inside
/// an individual SPM package — for example, that the app's dependency graph
/// assembles correctly from the composition root.
@Suite("Nerve App Smoke Tests")
struct NerveTests {

  // MARK: - Persistence Layer

  /// The schema used to bootstrap `ModelContainer` must never be empty.
  ///
  /// An empty schema does not crash immediately, but `ModelContainer` will
  /// throw at runtime when any `@Model` type is first accessed.
  /// This test catches a forgotten registration before the app ships.
  @Test("ModelRegistry.allModels is non-empty at app level")
  func modelRegistryNonEmpty() {
    #expect(
      !ModelRegistry.allModels.isEmpty,
      "Add your new @Model to ModelRegistry.allModels in StorageLayer/ModelRegistry.swift"
    )
  }

  /// Ensures the number of registered models matches the expected count.
  ///
  /// When a new `@Model` is added, this test forces the developer to
  /// acknowledge the change. Increment the expected count after verifying
  /// the new model is in ``ModelRegistry/allModels`` and the migration plan.
  @Test("ModelRegistry contains exactly the expected number of models")
  func modelRegistryCount() {
    #expect(
      ModelRegistry.allModels.count == 1,
      "Update this count and NerveSchemaMigrationPlan when adding new @Model types."
    )
  }

  // MARK: - DI Container

  @Test("DependencyContainer registers and resolves a service")
  func dependencyContainerRoundTrip() async throws {
    let container = DependencyContainer()
    await container.register(NewsServiceProtocol.self) { StubNewsService() }
    let service = try await container.resolve(NewsServiceProtocol.self)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 50_000)!
    let results = try await service.fetchNews(for: region)
    #expect(results.isEmpty)
  }

  @Test("DependencyContainer resolves singleton only once")
  func singletonResolveOnce() async throws {
    let container = DependencyContainer()
    let callCount = CallCounter()

    await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
      await callCount.increment()
      return StubNewsService()
    }

    _ = try await container.resolve(NewsServiceProtocol.self)
    _ = try await container.resolve(NewsServiceProtocol.self)
    _ = try await container.resolve(NewsServiceProtocol.self)

    let count = await callCount.count
    #expect(count == 1, "Singleton factory should be called exactly once")
  }

  // MARK: - GeoCoordinate Validation

  @Test("GeoCoordinate rejects out-of-range latitude")
  func geoCoordinateInvalidLatitude() {
    #expect(GeoCoordinate(latitude: 91.0, longitude: 0.0) == nil)
    #expect(GeoCoordinate(latitude: -91.0, longitude: 0.0) == nil)
  }

  @Test("GeoCoordinate rejects out-of-range longitude")
  func geoCoordinateInvalidLongitude() {
    #expect(GeoCoordinate(latitude: 0.0, longitude: 181.0) == nil)
    #expect(GeoCoordinate(latitude: 0.0, longitude: -181.0) == nil)
  }

  @Test("GeoCoordinate accepts boundary values")
  func geoCoordinateBoundaryValues() {
    #expect(GeoCoordinate(latitude: 90.0, longitude: 180.0) != nil)
    #expect(GeoCoordinate(latitude: -90.0, longitude: -180.0) != nil)
    #expect(GeoCoordinate(latitude: 0.0, longitude: 0.0) != nil)
  }

  // MARK: - Error System

  @Test("NerveError network variant carries reason")
  func nerveErrorNetworkReason() {
    let error = NerveError.network(message: "timeout", reason: .timeout)
    if case .network(_, let reason) = error {
      #expect(reason == .timeout)
    } else {
      Issue.record("Expected .network variant")
    }
  }

  @Test("NerveError storage variant preserves message")
  func nerveErrorStorageMessage() {
    let error = NerveError.storage(message: "save failed")
    #expect(error.localizedDescription.contains("save failed"))
  }

  // MARK: - StorageServiceProtocol Conformance

  @Test("StorageServiceProtocol deleteAllNews is callable")
  func deleteAllNewsCallable() async throws {
    let service = StubStorageService()
    let count = try await service.deleteAllNews()
    #expect(count == 0, "Stub should return 0 deletions")
  }
}

// MARK: - Test Helpers

private struct StubNewsService: NewsServiceProtocol {
  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] { [] }
  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(message: "Not implemented")
  }
}

private struct StubStorageService: StorageServiceProtocol {
  func saveNews(_ items: [NewsItem]) async throws {}
  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] { [] }
  func deleteNews(id: String) async throws {}
  func pruneExpiredCache() async throws {}
  @discardableResult
  func deleteAllNews() async throws -> Int { 0 }
}

/// Actor-isolated call counter for thread-safe test assertions.
private actor CallCounter {
  var count = 0
  func increment() { count += 1 }
}
