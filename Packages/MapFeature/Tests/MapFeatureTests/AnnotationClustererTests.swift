//
//  AnnotationClustererTests.swift
//  MapFeatureTests
//
//  Tests for the AnnotationClusterer actor, covering clustering correctness,
//  spatial granularity, and merge-radius exponential decay.
//

import Core
import Testing

@testable import MapFeature

@Suite("AnnotationClusterer Tests")
struct AnnotationClustererTests {

  let clusterer = AnnotationClusterer()

  private var defaultRegion: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!,
      radiusMeters: 50_000
    )!
  }

  // MARK: Edge Cases

  @Test("Empty items returns empty clusters")
  func emptyInput() async throws {
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10_000)!
    let clusters = try await clusterer.cluster(items: [], in: region, zoomLevel: 10)
    #expect(clusters.isEmpty)
  }

  @Test("Single item returns single non-cluster")
  func singleItem() async throws {
    let item = TestFixtures.makeItem(latitude: 41.0, longitude: 29.0)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10_000)!
    let clusters = try await clusterer.cluster(items: [item], in: region, zoomLevel: 10)
    #expect(clusters.count == 1)
    #expect(!clusters.first!.isCluster)
  }

  // MARK: Spatial Clustering

  @Test("Nearby items merge into a cluster at low zoom")
  func nearbyItemsMerge() async throws {
    let items = TestFixtures.makeItems(count: 5, nearLat: 41.0, nearLon: 29.0)
    let clusters = try await clusterer.cluster(
      items: items, in: defaultRegion, zoomLevel: 5)
    #expect(clusters.count < items.count)
  }

  @Test("Distant items remain separate at high zoom")
  func distantItemsSeparate() async throws {
    let items = [
      TestFixtures.makeItem(id: "ist", latitude: 41.0, longitude: 29.0),
      TestFixtures.makeItem(id: "tok", latitude: 35.6, longitude: 139.7),
      TestFixtures.makeItem(id: "nyc", latitude: 40.7, longitude: -74.0),
    ]
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 0, longitude: 0)!, radiusMeters: 20_000_000)!
    let clusters = try await clusterer.cluster(items: items, in: region, zoomLevel: 5)
    #expect(clusters.count == 3)
  }

  @Test("Zoom level affects clustering granularity")
  func zoomAffectsGranularity() async throws {
    let items = TestFixtures.makeItems(count: 10, nearLat: 41.0, nearLon: 29.0)
    let lowZoomClusters = try await clusterer.cluster(
      items: items, in: defaultRegion, zoomLevel: 3)
    let highZoomClusters = try await clusterer.cluster(
      items: items, in: defaultRegion, zoomLevel: 15)
    // High zoom → finer granularity → more (smaller) clusters.
    #expect(highZoomClusters.count >= lowZoomClusters.count)
  }

  @Test("All items are accounted for in cluster output")
  func allItemsAccountedFor() async throws {
    let items = TestFixtures.makeItems(count: 20, nearLat: 41.0, nearLon: 29.0)
    let clusters = try await clusterer.cluster(
      items: items, in: defaultRegion, zoomLevel: 10)
    let totalItems = clusters.reduce(0) { $0 + $1.count }
    #expect(totalItems == 20)
  }

  // MARK: Merge Radius

  @Test("Merge radius decreases exponentially with zoom")
  func mergeRadiusDecay() async {
    let r0 = await clusterer.computeMergeRadius(for: 0)
    let r5 = await clusterer.computeMergeRadius(for: 5)
    let r10 = await clusterer.computeMergeRadius(for: 10)

    #expect(r0 > r5)
    #expect(r5 > r10)
    // baseMergeRadius / 2^5 = 1/32 → ratio must exceed 30.
    #expect(r0 / r5 > 30)
  }
}
