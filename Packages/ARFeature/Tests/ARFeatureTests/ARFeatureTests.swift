import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - Module Tests

@Suite("ARFeature Module Tests")
struct ARFeatureModuleTests {

  @Test("ARFeature module version is defined")
  func moduleVersion() {
    #expect(!ARFeature.version.isEmpty)
  }

  @Test("ARFeature can access Core domain types")
  func coreDomainAccess() {
    let coord = GeoCoordinate(latitude: 41.0082, longitude: 28.9784)
    #expect(coord != nil)

    let analysis = HeadlineAnalysis(
      clickbaitScore: 0.4, sentiment: .neutral, confidence: 0.85
    )
    #expect(analysis.credibilityLabel == .caution)
  }
}

// MARK: - DI Round-Trip Tests

@Suite("ARFeature DI Integration Tests")
struct ARFeatureDITests {

  let container = DependencyContainer()

  @Test("DI container registers and resolves a service from ARFeature context")
  func diRoundTrip() async throws {
    await container.register(LocationServiceProtocol.self) {
      StubLocationService()
    }

    let service = try await container.resolve(LocationServiceProtocol.self)
    let location = try await service.requestCurrentLocation()
    #expect(location.latitude == 41.0082)
    #expect(location.longitude == 28.9784)
  }

  @Test("DI container resolves multiple Core protocols independently")
  func multiProtocolResolution() async throws {
    await container.register(LocationServiceProtocol.self) {
      StubLocationService()
    }
    await container.register(AIAnalysisServiceProtocol.self) {
      StubAIAnalysisService()
    }

    let locationService = try await container.resolve(LocationServiceProtocol.self)
    let aiService = try await container.resolve(AIAnalysisServiceProtocol.self)

    let location = try await locationService.requestCurrentLocation()
    let analysis = try await aiService.analyzeHeadline("Test headline")

    #expect(location.latitude == 41.0082)
    #expect(analysis.clickbaitScore == 0.2)
  }

  @Test("Unregistered service throws DependencyError")
  func unregisteredThrows() async {
    await #expect(throws: DependencyError.self) {
      try await container.resolve(NewsServiceProtocol.self)
    }
  }
}

// MARK: - Protocol Conformance Stubs

/// Compile-time verification that `LocationServiceProtocol` can be
/// implemented from an AR-context consumer.
actor StubLocationService: LocationServiceProtocol {

  private let _storedLocation: GeoCoordinate? = GeoCoordinate(
    latitude: 41.0082, longitude: 28.9784
  )

  func currentLocation() async throws -> GeoCoordinate? {
    _storedLocation
  }

  func startTracking() async throws {}

  func stopTracking() async {}

  func requestCurrentLocation() async throws -> GeoCoordinate {
    guard let location = _storedLocation else {
      throw NerveError.location(message: "Stub: no location available")
    }
    return location
  }
}

/// Compile-time verification that `AIAnalysisServiceProtocol` can be
/// implemented from an AR-context consumer.
struct StubAIAnalysisService: AIAnalysisServiceProtocol {

  func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis {
    HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.9)
  }

  func analyzeBatch(_ headlines: [String]) async throws -> [HeadlineAnalysis] {
    headlines.map { _ in
      HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.9)
    }
  }
}
