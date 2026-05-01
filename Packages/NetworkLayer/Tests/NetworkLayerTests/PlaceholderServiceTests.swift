//
//  PlaceholderServiceTests.swift
//  NetworkLayerTests
//
//  Tests for placeholder services that live in NetworkLayer until
//  production implementations are available.
//

import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - PlaceholderServiceTests

@Suite("NetworkLayer Placeholder Services")
struct PlaceholderServiceTests {

  // MARK: - PlaceholderNewsService

  @Test("PlaceholderNewsService returns empty items array")
  func newsServiceReturnsEmpty() async throws {
    let service = PlaceholderNewsService()
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
    let items = try await service.fetchNews(for: region)
    #expect(items.isEmpty, "Placeholder should return empty array, not crash")
  }

  @Test("PlaceholderNewsService fetchNewsDetail throws NerveError.network")
  func newsServiceDetailThrows() async {
    let service = PlaceholderNewsService()
    do {
      _ = try await service.fetchNewsDetail(id: "test-id")
      Issue.record("Should have thrown")
    } catch let error as NerveError {
      if case .network = error {
        // Expected
      } else {
        Issue.record("Expected NerveError.network, got \(error)")
      }
    } catch {
      Issue.record("Expected NerveError, got \(error)")
    }
  }

  // MARK: - PlaceholderImageService

  @Test("PlaceholderImageService returns empty data")
  func imageServiceReturnsEmptyData() async throws {
    let service = PlaceholderImageService()
    let data = try await service.loadImage(
      from: URL(string: "https://example.com/image.jpg")!
    )
    #expect(data.isEmpty, "Placeholder should return empty data, not crash")
  }

  @Test("PlaceholderImageService clearCache does not throw")
  func imageServiceClearCacheNoThrow() async {
    let service = PlaceholderImageService()
    await service.clearCache()
    // No crash = success
  }
}
