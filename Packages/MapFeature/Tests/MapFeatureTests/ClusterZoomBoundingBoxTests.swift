//
//  ClusterZoomBoundingBoxTests.swift
//  MapFeatureTests
//
//  Tests the bounding-box zoom math used in NerveMapView.Coordinator's
//  cluster-selection handler. These tests are pure coordinate arithmetic —
//  no UIKit or MapKit import required.
//

import Core
import Testing

@testable import MapFeature

/// Tests for the zoom-to-cluster bounding region calculation.
///
/// The `boundingRegion` helper mirrors the production logic in
/// `NerveMapView.Coordinator` so these tests act as a specification
/// that must be kept in sync with any future changes to that method.
@Suite("Cluster Zoom Bounding Box Tests")
struct ClusterZoomBoundingBoxTests {

  // MARK: - Helper (mirrors production logic)

  /// Computes the padded bounding region that fits all `items`.
  ///
  /// Mirrors the production logic in `NerveMapView.Coordinator` exactly.
  /// If the array is empty, returns `nil`.
  private func boundingRegion(for items: [NewsItem], padding: Double = 0.20)
    -> (centerLat: Double, centerLon: Double, spanLat: Double, spanLon: Double)?
  {
    guard !items.isEmpty else { return nil }
    var minLat = items[0].coordinate.latitude
    var maxLat = items[0].coordinate.latitude
    var minLon = items[0].coordinate.longitude
    var maxLon = items[0].coordinate.longitude
    for item in items {
      minLat = min(minLat, item.coordinate.latitude)
      maxLat = max(maxLat, item.coordinate.latitude)
      minLon = min(minLon, item.coordinate.longitude)
      maxLon = max(maxLon, item.coordinate.longitude)
    }
    let latPad = (maxLat - minLat) * padding + 0.002
    let lonPad = (maxLon - minLon) * padding + 0.002
    return (
      centerLat: (minLat + maxLat) / 2,
      centerLon: (minLon + maxLon) / 2,
      spanLat: (maxLat - minLat) + latPad,
      spanLon: (maxLon - minLon) + lonPad
    )
  }

  // MARK: Tests

  @Test("Center of bounding box is the midpoint of all item coordinates")
  func boundingBoxCenter() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 30.0),
    ]
    let box = boundingRegion(for: items)!
    #expect(box.centerLat == 41.0, "Center latitude must be the midpoint")
    #expect(box.centerLon == 29.0, "Center longitude must be the midpoint")
  }

  @Test("Span includes 20% padding on each axis plus 0.002° baseline")
  func boundingBoxSpanHasPadding() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 30.0),
    ]
    let box = boundingRegion(for: items)!
    // Raw deltas: latDelta = 2.0, lonDelta = 2.0
    // Padding = delta * 0.20 + 0.002 = 0.402
    let expectedSpanLat = 2.0 + (2.0 * 0.20 + 0.002)
    let expectedSpanLon = 2.0 + (2.0 * 0.20 + 0.002)
    #expect(abs(box.spanLat - expectedSpanLat) < 1e-9)
    #expect(abs(box.spanLon - expectedSpanLon) < 1e-9)
  }

  @Test("Single item produces a minimum positive span from the baseline padding")
  func singleItemBaselinePadding() {
    let items = [TestFixtures.makeItem(id: "a", latitude: 41.0, longitude: 29.0)]
    let box = boundingRegion(for: items)!
    // Single item: deltas = 0 → span = 0.002 constant → ensures visible context.
    #expect(box.spanLat > 0, "Span must be positive even for a single item")
    #expect(box.spanLon > 0, "Span must be positive even for a single item")
  }

  @Test("Empty item list returns nil")
  func emptyItemsNilRegion() {
    #expect(boundingRegion(for: []) == nil)
  }

  @Test("Padded span covers every item in the cluster")
  func largeCoverageSpan() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 35.0, longitude: 26.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 44.0),
      TestFixtures.makeItem(id: "c", latitude: 38.0, longitude: 39.0),
    ]
    let box = boundingRegion(for: items)!
    for item in items {
      let halfLat = box.spanLat / 2
      let halfLon = box.spanLon / 2
      #expect(item.coordinate.latitude >= box.centerLat - halfLat)
      #expect(item.coordinate.latitude <= box.centerLat + halfLat)
      #expect(item.coordinate.longitude >= box.centerLon - halfLon)
      #expect(item.coordinate.longitude <= box.centerLon + halfLon)
    }
  }
}
