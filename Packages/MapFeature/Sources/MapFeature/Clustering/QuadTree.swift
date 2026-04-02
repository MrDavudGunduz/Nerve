//
//  QuadTree.swift
//  MapFeature
//
//  Created by Davud Gunduz on 31.03.2026.
//

import Core
import Foundation

// MARK: - BoundingBox

/// An axis-aligned bounding rectangle in geographic coordinate space.
///
/// Used as the spatial domain for quad-tree subdivision.
/// Coordinates use WGS-84 decimal degrees (latitude: −90…+90, longitude: −180…+180).
///
/// - Note: Internal to `MapFeature` — this is an implementation detail of
///   ``AnnotationClusterer`` and is not part of the public API surface.
struct BoundingBox: Sendable, Hashable {

  /// Minimum latitude (south edge).
  let minLat: Double

  /// Maximum latitude (north edge).
  let maxLat: Double

  /// Minimum longitude (west edge).
  let minLon: Double

  /// Maximum longitude (east edge).
  let maxLon: Double

  /// Creates a bounding box from the given edges.
  ///
  /// - Precondition: `minLat <= maxLat` and `minLon <= maxLon`.
  init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
    precondition(minLat <= maxLat, "BoundingBox: minLat (\(minLat)) must be ≤ maxLat (\(maxLat))")
    precondition(minLon <= maxLon, "BoundingBox: minLon (\(minLon)) must be ≤ maxLon (\(maxLon))")
    self.minLat = minLat
    self.maxLat = maxLat
    self.minLon = minLon
    self.maxLon = maxLon
  }

  /// The midpoint latitude of this box.
  var midLat: Double { (minLat + maxLat) / 2.0 }

  /// The midpoint longitude of this box.
  var midLon: Double { (minLon + maxLon) / 2.0 }

  /// The latitudinal span of this box in degrees.
  var latSpan: Double { maxLat - minLat }

  /// The longitudinal span of this box in degrees.
  var lonSpan: Double { maxLon - minLon }

  /// Whether the given coordinate falls within (or on the boundary of) this box.
  func contains(latitude: Double, longitude: Double) -> Bool {
    latitude >= minLat && latitude <= maxLat
      && longitude >= minLon && longitude <= maxLon
  }

  /// Whether this box overlaps with `other`.
  func intersects(_ other: BoundingBox) -> Bool {
    !(other.minLat > maxLat || other.maxLat < minLat
      || other.minLon > maxLon || other.maxLon < minLon)
  }
}

// MARK: - QuadTree

/// A spatial index that partitions 2D geographic space into quadrants
/// for efficient point queries and range searches.
///
/// Designed for clustering news annotations on a map:
/// - **Insert:** O(log n) amortized — each point walks down the tree depth.
/// - **Range query:** O(n·log n) worst-case, typically much faster when
///   the query region is small relative to the data extent.
///
/// The tree is rebuilt per clustering pass (not long-lived), so mutation
/// performance is secondary to query speed.
///
/// - Note: Internal to `MapFeature`. Exposing this type publicly would allow
///   external callers to mutate `entries`/`children` off the actor executor,
///   causing a data race. All access is serialized by ``AnnotationClusterer``'s
///   actor isolation.
final class QuadTree<Element: Sendable> {

  // MARK: - Types

  /// A point stored in the tree alongside its element payload.
  struct Entry: Sendable {
    let latitude: Double
    let longitude: Double
    let element: Element
  }

  // MARK: - Configuration

  /// Maximum elements per node before subdivision.
  private let nodeCapacity: Int

  /// Maximum depth to prevent infinite subdivision on co-located points.
  private let maxDepth: Int

  // MARK: - State

  /// The spatial domain of this node.
  let boundary: BoundingBox

  /// The current depth in the tree (root = 0).
  private let depth: Int

  /// Points stored in this leaf node.
  private var entries: [Entry]

  /// Child quadrants. `nil` until subdivision occurs.
  private var children: [QuadTree]?

  // MARK: - Init

  /// Creates a new quad-tree for the given bounding box.
  ///
  /// - Parameters:
  ///   - boundary: The spatial domain of this tree node.
  ///   - nodeCapacity: Max elements per leaf before splitting (default: 4).
  ///   - maxDepth: Maximum recursion depth (default: 12).
  init(
    boundary: BoundingBox,
    nodeCapacity: Int = 4,
    maxDepth: Int = 12
  ) {
    self.boundary = boundary
    self.nodeCapacity = nodeCapacity
    self.maxDepth = maxDepth
    self.depth = 0
    self.entries = []
  }

  /// Internal initializer with depth tracking.
  private init(
    boundary: BoundingBox,
    nodeCapacity: Int,
    maxDepth: Int,
    depth: Int
  ) {
    self.boundary = boundary
    self.nodeCapacity = nodeCapacity
    self.maxDepth = maxDepth
    self.depth = depth
    self.entries = []
  }

  // MARK: - Insert

  /// Inserts an element at the given geographic coordinate.
  ///
  /// If the point falls outside this node's boundary, it is silently
  /// ignored (out-of-bounds points are common when the map region
  /// doesn't cover the full data extent).
  ///
  /// - Parameters:
  ///   - element: The data payload to store.
  ///   - latitude: Latitude in decimal degrees.
  ///   - longitude: Longitude in decimal degrees.
  @discardableResult
  func insert(_ element: Element, at latitude: Double, longitude: Double) -> Bool {
    guard boundary.contains(latitude: latitude, longitude: longitude) else {
      return false
    }

    // If there are children, delegate to the appropriate quadrant.
    if let children {
      for child in children {
        if child.insert(element, at: latitude, longitude: longitude) {
          return true
        }
      }
      return false
    }

    // Leaf node: store if under capacity or at max depth.
    if entries.count < nodeCapacity || depth >= maxDepth {
      entries.append(Entry(latitude: latitude, longitude: longitude, element: element))
      return true
    }

    // Subdivide and redistribute.
    subdivide()
    entries.append(Entry(latitude: latitude, longitude: longitude, element: element))
    redistributeEntries()
    return true
  }

  // MARK: - Query

  /// Returns all elements whose insertion point falls within the given region.
  ///
  /// - Parameter region: The query bounding box.
  /// - Returns: Array of elements within the region.
  func query(in region: BoundingBox) -> [Element] {
    var results: [Element] = []
    queryRecursive(in: region, results: &results)
    return results
  }

  /// Recursive helper that appends matching elements to a shared array.
  private func queryRecursive(in region: BoundingBox, results: inout [Element]) {
    guard boundary.intersects(region) else { return }

    for entry in entries where region.contains(latitude: entry.latitude, longitude: entry.longitude)
    {
      results.append(entry.element)
    }

    if let children {
      for child in children {
        child.queryRecursive(in: region, results: &results)
      }
    }
  }

  /// Returns all elements stored in the tree (flattened).
  func allElements() -> [Element] {
    var results: [Element] = []
    allElementsRecursive(results: &results)
    return results
  }

  /// Recursive helper that appends all elements to a shared array.
  private func allElementsRecursive(results: inout [Element]) {
    for entry in entries {
      results.append(entry.element)
    }
    if let children {
      for child in children {
        child.allElementsRecursive(results: &results)
      }
    }
  }

  /// Returns all entries (with coordinates) stored in the tree.
  func allEntries() -> [Entry] {
    var results: [Entry] = []
    allEntriesRecursive(results: &results)
    return results
  }

  /// Recursive helper that appends all entries to a shared array.
  private func allEntriesRecursive(results: inout [Entry]) {
    results.append(contentsOf: entries)
    if let children {
      for child in children {
        child.allEntriesRecursive(results: &results)
      }
    }
  }

  // MARK: - Private

  private func subdivide() {
    let midLat = boundary.midLat
    let midLon = boundary.midLon
    let nextDepth = depth + 1

    children = [
      // NW
      QuadTree(
        boundary: BoundingBox(
          minLat: midLat, maxLat: boundary.maxLat,
          minLon: boundary.minLon, maxLon: midLon
        ),
        nodeCapacity: nodeCapacity, maxDepth: maxDepth, depth: nextDepth
      ),
      // NE
      QuadTree(
        boundary: BoundingBox(
          minLat: midLat, maxLat: boundary.maxLat,
          minLon: midLon, maxLon: boundary.maxLon
        ),
        nodeCapacity: nodeCapacity, maxDepth: maxDepth, depth: nextDepth
      ),
      // SW
      QuadTree(
        boundary: BoundingBox(
          minLat: boundary.minLat, maxLat: midLat,
          minLon: boundary.minLon, maxLon: midLon
        ),
        nodeCapacity: nodeCapacity, maxDepth: maxDepth, depth: nextDepth
      ),
      // SE
      QuadTree(
        boundary: BoundingBox(
          minLat: boundary.minLat, maxLat: midLat,
          minLon: midLon, maxLon: boundary.maxLon
        ),
        nodeCapacity: nodeCapacity, maxDepth: maxDepth, depth: nextDepth
      ),
    ]
  }

  private func redistributeEntries() {
    guard let children else { return }
    let entriesToRedistribute = entries
    entries = []

    for entry in entriesToRedistribute {
      // Boundary-edge points always land in the first matching child
      // because contains() uses >= / <= and children share midpoints.
      for child in children {
        if child.insert(entry.element, at: entry.latitude, longitude: entry.longitude) {
          break
        }
      }
    }
  }
}
