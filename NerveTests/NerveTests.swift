//
//  NerveTests.swift
//  NerveTests
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core
import StorageLayer
import Testing

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

  // MARK: - DI Container

  @Test("DependencyContainer registers and resolves a service")
  func dependencyContainerRoundTrip() async throws {
    let container = DependencyContainer()
    await container.register(NewsServiceProtocol.self) { StubNewsService() }
    let service = try await container.resolve(NewsServiceProtocol.self)
    let results = try await service.fetchHeadlines(in: nil, limit: 1)
    #expect(results.isEmpty)
  }

  // MARK: - GeoCoordinate Validation

  @Test("GeoCoordinate rejects out-of-range latitude")
  func geoCoordinateInvalidLatitude() {
    #expect(GeoCoordinate(latitude:  91.0, longitude:   0.0) == nil)
    #expect(GeoCoordinate(latitude: -91.0, longitude:   0.0) == nil)
  }

  @Test("GeoCoordinate rejects out-of-range longitude")
  func geoCoordinateInvalidLongitude() {
    #expect(GeoCoordinate(latitude: 0.0, longitude:  181.0) == nil)
    #expect(GeoCoordinate(latitude: 0.0, longitude: -181.0) == nil)
  }

  @Test("GeoCoordinate accepts boundary values")
  func geoCoordinateBoundaryValues() {
    #expect(GeoCoordinate(latitude:  90.0, longitude:  180.0) != nil)
    #expect(GeoCoordinate(latitude: -90.0, longitude: -180.0) != nil)
    #expect(GeoCoordinate(latitude:   0.0, longitude:    0.0) != nil)
  }
}

// MARK: - Stub

private struct StubNewsService: NewsServiceProtocol {
  func fetchHeadlines(in region: GeoRegion?, limit: Int?) async throws -> [NewsItem] { [] }
  func fetchDetails(id: String) async throws -> NewsItem? { nil }
  func refreshCache(in region: GeoRegion?) async throws {}
}
