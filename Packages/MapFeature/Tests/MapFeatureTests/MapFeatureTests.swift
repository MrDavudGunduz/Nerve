import Core
import Foundation
import Testing

@testable import MapFeature

// MARK: - Module Tests

@Suite("MapFeature Module Tests")
struct MapFeatureModuleTests {

  @Test("MapFeature module version is defined")
  func moduleVersion() {
    #expect(!MapFeature.version.isEmpty)
  }
}

// MARK: - Protocol Conformance Stub

/// Compile-time verification that `LocationServiceProtocol` can be implemented.
actor StubLocationService: LocationServiceProtocol {

  var currentLocation: GeoCoordinate? {
    GeoCoordinate(latitude: 41.0082, longitude: 28.9784)
  }

  func startTracking() async throws {}

  func stopTracking() async {}

  func requestCurrentLocation() async throws -> GeoCoordinate {
    guard let location = currentLocation else {
      throw NerveError.location(message: "Stub: no location available")
    }
    return location
  }
}

// MARK: - DI Round-Trip Tests

@Suite("MapFeature Protocol Conformance Tests")
struct MapFeatureProtocolTests {

  let container = DependencyContainer()

  @Test("StubLocationService conforms to LocationServiceProtocol and resolves via DI")
  func locationServiceRoundTrip() async throws {
    await container.register(LocationServiceProtocol.self) {
      StubLocationService()
    }

    let service = try await container.resolve(LocationServiceProtocol.self)
    let location = try await service.requestCurrentLocation()
    #expect(location.latitude == 41.0082)
    #expect(location.longitude == 28.9784)
  }
}
