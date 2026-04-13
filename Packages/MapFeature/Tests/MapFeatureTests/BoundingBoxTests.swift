//
//  BoundingBoxTests.swift
//  MapFeatureTests
//
//  Tests for the BoundingBox spatial primitive used by QuadTree.
//

import Core
import Testing

@testable import MapFeature

@Suite("BoundingBox Tests")
struct BoundingBoxTests {

  // MARK: Contains

  @Test("Contains point inside boundary")
  func containsInside() {
    let box = BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10)
    #expect(box.contains(latitude: 5, longitude: 5))
  }

  @Test("Contains point on boundary edge")
  func containsEdge() {
    let box = BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10)
    #expect(box.contains(latitude: 0, longitude: 0))
    #expect(box.contains(latitude: 10, longitude: 10))
  }

  @Test("Rejects point outside boundary")
  func rejectsOutside() {
    let box = BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10)
    #expect(!box.contains(latitude: -1, longitude: 5))
    #expect(!box.contains(latitude: 5, longitude: 11))
  }

  // MARK: Intersection

  @Test("Intersects overlapping boxes")
  func intersectsOverlap() {
    let a = BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10)
    let b = BoundingBox(minLat: 5, maxLat: 15, minLon: 5, maxLon: 15)
    #expect(a.intersects(b))
    #expect(b.intersects(a))
  }

  @Test("Does not intersect disjoint boxes")
  func noIntersect() {
    let a = BoundingBox(minLat: 0, maxLat: 5, minLon: 0, maxLon: 5)
    let b = BoundingBox(minLat: 10, maxLat: 15, minLon: 10, maxLon: 15)
    #expect(!a.intersects(b))
  }

  // MARK: Span

  @Test("Span calculations are correct")
  func spans() {
    let box = BoundingBox(minLat: 10, maxLat: 30, minLon: 40, maxLon: 100)
    #expect(box.latSpan == 20)
    #expect(box.lonSpan == 60)
  }
}
