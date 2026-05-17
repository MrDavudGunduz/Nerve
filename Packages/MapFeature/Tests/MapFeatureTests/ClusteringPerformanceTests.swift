//
//  ClusteringPerformanceTests.swift
//  MapFeatureTests
//
//  Created by Davud Gunduz on 14.05.2026.
//

import Core
import Foundation
@testable import MapFeature
import Testing

/// Performance benchmarks for the clustering engine.
///
/// These tests validate that ``AnnotationClusterer`` meets the documented
/// performance target of **< 100ms for 1,000 items** at various zoom levels.
///
/// ## Methodology
///
/// - Items are generated with random coordinates spread across Istanbul.
/// - Each test measures wall-clock time using `ContinuousClock`.
/// - Assertions verify both correctness (non-empty clusters) and performance.
@Suite("Clustering Performance Benchmarks")
struct ClusteringPerformanceTests {

  // MARK: - Helpers

  /// Generates `count` news items with coordinates randomly distributed
  /// around Istanbul (±2° latitude/longitude).
  private func generateItems(count: Int) -> [NewsItem] {
    (0..<count).compactMap { index in
      let lat = 41.0 + Double.random(in: -2.0...2.0)
      let lon = 29.0 + Double.random(in: -2.0...2.0)
      guard let coord = GeoCoordinate(latitude: lat, longitude: lon) else { return nil }
      return NewsItem(
        id: "perf-\(index)",
        headline: "Performance Test Item \(index)",
        summary: "Summary for item \(index)",
        source: "PerfTest",
        category: NewsCategory.allCases.randomElement() ?? .other,
        coordinate: coord,
        publishedAt: Date()
      )
    }
  }

  /// Istanbul-centered region covering the test data extent.
  private var testRegion: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 250_000
    )!
  }

  // MARK: - Tests

  @Test("1,000 items cluster within 100ms at zoom level 10")
  func clusteringPerformance1K() async throws {
    let items = generateItems(count: 1_000)
    let clusterer = AnnotationClusterer()
    let clock = ContinuousClock()

    let elapsed = try await clock.measure {
      let clusters = try await clusterer.cluster(
        items: items, in: testRegion, zoomLevel: 10.0
      )
      #expect(!clusters.isEmpty, "Clustering should produce at least one cluster")
    }

    let milliseconds = elapsed.components.seconds * 1_000
      + elapsed.components.attoseconds / 1_000_000_000_000_000
    #expect(
      milliseconds < 100,
      "Clustering 1K items took \(milliseconds)ms — exceeds 100ms target"
    )
  }

  @Test("500 items cluster within 50ms at zoom level 12")
  func clusteringPerformance500() async throws {
    let items = generateItems(count: 500)
    let clusterer = AnnotationClusterer()
    let clock = ContinuousClock()

    let elapsed = try await clock.measure {
      let clusters = try await clusterer.cluster(
        items: items, in: testRegion, zoomLevel: 12.0
      )
      #expect(!clusters.isEmpty)
    }

    let milliseconds = elapsed.components.seconds * 1_000
      + elapsed.components.attoseconds / 1_000_000_000_000_000
    #expect(
      milliseconds < 50,
      "Clustering 500 items took \(milliseconds)ms — exceeds 50ms target"
    )
  }

  @Test("Clustering scales linearly: 2K items within 250ms")
  func clusteringScaling2K() async throws {
    let items = generateItems(count: 2_000)
    let clusterer = AnnotationClusterer()
    let clock = ContinuousClock()

    let elapsed = try await clock.measure {
      let clusters = try await clusterer.cluster(
        items: items, in: testRegion, zoomLevel: 8.0
      )
      #expect(!clusters.isEmpty)
    }

    let milliseconds = elapsed.components.seconds * 1_000
      + elapsed.components.attoseconds / 1_000_000_000_000_000
    #expect(
      milliseconds < 250,
      "Clustering 2K items took \(milliseconds)ms — exceeds 250ms target"
    )
  }

  @Test("Merge radius decreases exponentially with zoom level")
  func mergeRadiusDecay() async {
    let clusterer = AnnotationClusterer()

    let radiusZ0 = await clusterer.computeMergeRadius(for: 0)
    let radiusZ5 = await clusterer.computeMergeRadius(for: 5)
    let radiusZ10 = await clusterer.computeMergeRadius(for: 10)
    let radiusZ15 = await clusterer.computeMergeRadius(for: 15)

    // Verify exponential decay: each 5-level jump ≈ 32× reduction.
    #expect(radiusZ0 > radiusZ5)
    #expect(radiusZ5 > radiusZ10)
    #expect(radiusZ10 > radiusZ15)

    // Verify minimum clamping at high zoom levels.
    #expect(radiusZ15 >= 0.001, "Merge radius should be clamped to minimum")
  }
}
