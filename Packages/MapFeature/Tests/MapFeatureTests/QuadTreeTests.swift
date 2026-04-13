//
//  QuadTreeTests.swift
//  MapFeatureTests
//
//  Tests for the QuadTree spatial index used by AnnotationClusterer.
//

import Core
import Testing

@testable import MapFeature

@Suite("QuadTree Tests")
struct QuadTreeTests {

  /// World-bounds boundary reused across all QuadTree tests.
  let worldBounds = BoundingBox(minLat: -90, maxLat: 90, minLon: -180, maxLon: 180)

  // MARK: Basic Insert / Query

  @Test("Insert and query single element")
  func singleInsertQuery() {
    let tree = QuadTree<String>(boundary: worldBounds)
    let inserted = tree.insert("Istanbul", at: 41.0, longitude: 29.0)
    #expect(inserted)

    let results = tree.query(in: BoundingBox(minLat: 40, maxLat: 42, minLon: 28, maxLon: 30))
    #expect(results.count == 1)
    #expect(results.first == "Istanbul")
  }

  @Test("Insert outside boundary returns false")
  func insertOutOfBounds() {
    let tree = QuadTree<String>(
      boundary: BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10))
    let inserted = tree.insert("Outside", at: 50, longitude: 50)
    #expect(!inserted)
  }

  @Test("Query empty tree returns empty array")
  func queryEmpty() {
    let tree = QuadTree<String>(boundary: worldBounds)
    let results = tree.query(in: worldBounds)
    #expect(results.isEmpty)
  }

  // MARK: Subdivision

  @Test("Insert many elements triggers subdivision")
  func subdivisionOnCapacity() {
    let tree = QuadTree<Int>(boundary: worldBounds, nodeCapacity: 2)
    for i in 0..<10 {
      tree.insert(i, at: Double(i) * 5, longitude: Double(i) * 10)
    }
    let all = tree.allElements()
    #expect(all.count == 10)
  }

  // MARK: Spatial Correctness

  @Test("Query returns only elements in region")
  func spatialQuery() {
    let tree = QuadTree<String>(boundary: worldBounds)
    tree.insert("Istanbul", at: 41.0, longitude: 29.0)
    tree.insert("Tokyo", at: 35.6, longitude: 139.7)
    tree.insert("NYC", at: 40.7, longitude: -74.0)

    let europeQuery = BoundingBox(minLat: 35, maxLat: 72, minLon: -10, maxLon: 45)
    let results = tree.query(in: europeQuery)
    #expect(results.count == 1)
    #expect(results.first == "Istanbul")
  }

  @Test("Co-located points handled correctly")
  func colocatedPoints() {
    let tree = QuadTree<Int>(boundary: worldBounds, nodeCapacity: 2, maxDepth: 4)
    for i in 0..<20 {
      tree.insert(i, at: 41.0, longitude: 29.0)
    }
    let results = tree.allElements()
    #expect(results.count == 20)
  }

  // MARK: Performance

  @Test("1000+ elements insert and query efficiently")
  func performanceLargeDataset() {
    let tree = QuadTree<Int>(boundary: worldBounds)
    for i in 0..<1000 {
      let lat = Double.random(in: -90...90)
      let lon = Double.random(in: -180...180)
      tree.insert(i, at: lat, longitude: lon)
    }

    let all = tree.allElements()
    #expect(all.count == 1000)

    let smallRegion = BoundingBox(minLat: 40, maxLat: 42, minLon: 28, maxLon: 30)
    let subset = tree.query(in: smallRegion)
    #expect(subset.count <= 1000)
  }
}
