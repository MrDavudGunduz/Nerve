import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - Module Tests

@Suite("NetworkLayer Module Tests")
struct NetworkLayerModuleTests {

  @Test("NetworkLayer module version is defined")
  func moduleVersion() {
    #expect(!NetworkLayer.version.isEmpty)
  }
}

// MARK: - Protocol Conformance Stubs

/// Compile-time verification that `NewsServiceProtocol` can be implemented
/// by a consumer of `Core`. If this file compiles, the API contract is valid.
struct StubNewsService: NewsServiceProtocol {

  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] {
    []
  }

  func fetchNewsDetail(id: String) async throws -> NewsItem {
    NewsItem(
      id: id,
      headline: "Stub",
      summary: "Stub",
      source: "Stub",
      category: .other,
      coordinate: GeoCoordinate(latitude: 0, longitude: 0)!,
      publishedAt: Date()
    )
  }
}

/// Compile-time verification that `ImageServiceProtocol` can be implemented.
struct StubImageService: ImageServiceProtocol {

  func loadImage(from url: URL) async throws -> Data {
    Data()
  }

  func clearCache() async {}
}

// MARK: - DI Round-Trip Tests

@Suite("NetworkLayer Protocol Conformance Tests")
struct NetworkLayerProtocolTests {

  let container = DependencyContainer()

  @Test("StubNewsService conforms to NewsServiceProtocol and resolves via DI")
  func newsServiceRoundTrip() async throws {
    await container.register(NewsServiceProtocol.self) {
      StubNewsService()
    }

    let service = try await container.resolve(NewsServiceProtocol.self)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 1000
    )!
    let results = try await service.fetchNews(for: region)
    #expect(results.isEmpty)
  }

  @Test("StubImageService conforms to ImageServiceProtocol and resolves via DI")
  func imageServiceRoundTrip() async throws {
    await container.register(ImageServiceProtocol.self) {
      StubImageService()
    }

    let service = try await container.resolve(ImageServiceProtocol.self)
    let data = try await service.loadImage(from: URL(string: "https://example.com/img.png")!)
    #expect(data.isEmpty)
  }
}
