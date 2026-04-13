//
//  TestFixtures.swift
//  MapFeatureTests
//
//  Shared test fixture builder. Used by every test suite in MapFeatureTests.
//

import Core
import Foundation

@testable import MapFeature

// MARK: - TestFixtures

/// Shared factory for constructing deterministic ``NewsItem`` and related
/// model values across all test suites.
///
/// All parameters default to sensible, non-exceptional values so individual
/// tests only override the fields they care about.
enum TestFixtures {

  // MARK: - NewsItem

  /// Builds a single ``NewsItem`` with overrideable properties.
  ///
  /// - Parameters:
  ///   - id: Item identifier (default: new UUID string).
  ///   - headline: Article headline text (default: `"Test Headline"`).
  ///   - category: News category (default: `.technology`).
  ///   - latitude: Geographic latitude (default: `41.0` — Istanbul).
  ///   - longitude: Geographic longitude (default: `29.0` — Istanbul).
  ///   - analysis: Optional AI headline analysis (default: `nil`).
  static func makeItem(
    id: String = UUID().uuidString,
    headline: String = "Test Headline",
    category: NewsCategory = .technology,
    latitude: Double = 41.0,
    longitude: Double = 29.0,
    analysis: HeadlineAnalysis? = nil
  ) -> NewsItem {
    NewsItem(
      id: id,
      headline: headline,
      summary: "Test summary",
      source: "Test Source",
      category: category,
      coordinate: GeoCoordinate(latitude: latitude, longitude: longitude)!,
      publishedAt: Date(),
      analysis: analysis
    )
  }

  /// Builds an array of ``NewsItem`` instances clustered near a single point.
  ///
  /// Each item is offset by `0.001°` per index from the base coordinate,
  /// keeping items within a few hundred metres of each other.
  ///
  /// - Parameters:
  ///   - count: Number of items to generate.
  ///   - nearLat: Base latitude (default: `41.0`).
  ///   - nearLon: Base longitude (default: `29.0`).
  static func makeItems(count: Int, nearLat: Double = 41.0, nearLon: Double = 29.0) -> [NewsItem] {
    (0..<count).map { i in
      let offset = Double(i) * 0.001
      return makeItem(
        id: "item-\(i)",
        headline: "Headline \(i)",
        latitude: nearLat + offset,
        longitude: nearLon + offset
      )
    }
  }

  // MARK: - Shared Regions

  /// A standard Istanbul-area region used across multiple test suites.
  static var istanbulRegion: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
  }
}
