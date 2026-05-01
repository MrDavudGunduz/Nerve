//
//  MapViewModelStubs.swift
//  MapFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation

// MARK: - Internal Stubs (Preview / Test use only)

/// Minimal ``NewsServiceProtocol`` stub for ``MapViewModel``'s convenience init.
///
/// Returns empty results and is never registered in ``DependencyContainer``.
/// For app-level placeholder services, see ``NetworkLayer/PlaceholderNewsService``.
struct StubNewsServiceInternal: NewsServiceProtocol, Sendable {
  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] { [] }
  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(message: "StubNewsServiceInternal")
  }
}

/// Minimal ``StorageServiceProtocol`` stub for ``MapViewModel``'s convenience init.
struct StubStorageServiceInternal: StorageServiceProtocol, Sendable {
  func saveNews(_ items: [NewsItem]) async throws {}
  func fetchNews(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] { [] }
  func deleteNews(id: String) async throws {}
  func pruneExpiredCache() async throws {}
}

/// Minimal ``LocationServiceProtocol`` stub for ``MapViewModel``'s convenience init.
struct StubLocationServiceInternal: LocationServiceProtocol, Sendable {
  func currentLocation() async throws -> GeoCoordinate? { nil }
  func startTracking() async throws {}
  func stopTracking() async {}
  func requestCurrentLocation() async throws -> GeoCoordinate {
    GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!
  }
}
