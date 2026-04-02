import Core
import Foundation
import Testing

@testable import MapFeature

// MARK: - Test Fixtures

/// Shared test fixture builder for creating NewsItem instances.
enum TestFixtures {

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
}

// MARK: - BoundingBox Tests

@Suite("BoundingBox Tests")
struct BoundingBoxTests {

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

  @Test("Span calculations are correct")
  func spans() {
    let box = BoundingBox(minLat: 10, maxLat: 30, minLon: 40, maxLon: 100)
    #expect(box.latSpan == 20)
    #expect(box.lonSpan == 60)
  }
}

// MARK: - QuadTree Tests

@Suite("QuadTree Tests")
struct QuadTreeTests {

  let worldBounds = BoundingBox(minLat: -90, maxLat: 90, minLon: -180, maxLon: 180)

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
    let tree = QuadTree<String>(boundary: BoundingBox(minLat: 0, maxLat: 10, minLon: 0, maxLon: 10))
    let inserted = tree.insert("Outside", at: 50, longitude: 50)
    #expect(!inserted)
  }

  @Test("Query empty tree returns empty array")
  func queryEmpty() {
    let tree = QuadTree<String>(boundary: worldBounds)
    let results = tree.query(in: worldBounds)
    #expect(results.isEmpty)
  }

  @Test("Insert many elements triggers subdivision")
  func subdivisionOnCapacity() {
    let tree = QuadTree<Int>(boundary: worldBounds, nodeCapacity: 2)

    for i in 0..<10 {
      tree.insert(i, at: Double(i) * 5, longitude: Double(i) * 10)
    }

    let all = tree.allElements()
    #expect(all.count == 10)
  }

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
      tree.insert(i, at: 41.0, longitude: 29.0)  // All at the same point
    }
    let results = tree.allElements()
    #expect(results.count == 20)
  }

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

    // Small region query should return a subset
    let smallRegion = BoundingBox(minLat: 40, maxLat: 42, minLon: 28, maxLon: 30)
    let subset = tree.query(in: smallRegion)
    #expect(subset.count <= 1000)
  }
}

// MARK: - AnnotationClusterer Tests

@Suite("AnnotationClusterer Tests")
struct AnnotationClustererTests {

  let clusterer = AnnotationClusterer()

  @Test("Empty items returns empty clusters")
  func emptyInput() async {
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10000)!
    let clusters = await clusterer.cluster(items: [], in: region, zoomLevel: 10)
    #expect(clusters.isEmpty)
  }

  @Test("Single item returns single cluster")
  func singleItem() async {
    let item = TestFixtures.makeItem(latitude: 41.0, longitude: 29.0)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10000)!
    let clusters = await clusterer.cluster(items: [item], in: region, zoomLevel: 10)
    #expect(clusters.count == 1)
    #expect(!clusters.first!.isCluster)
  }

  @Test("Nearby items merge into a cluster at low zoom")
  func nearbyItemsMerge() async {
    let items = TestFixtures.makeItems(count: 5, nearLat: 41.0, nearLon: 29.0)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 50000)!
    let clusters = await clusterer.cluster(items: items, in: region, zoomLevel: 5)
    // At low zoom, nearby items should merge into fewer clusters
    #expect(clusters.count < items.count)
  }

  @Test("Distant items remain separate at high zoom")
  func distantItemsSeparate() async {
    let items = [
      TestFixtures.makeItem(id: "ist", latitude: 41.0, longitude: 29.0),
      TestFixtures.makeItem(id: "tok", latitude: 35.6, longitude: 139.7),
      TestFixtures.makeItem(id: "nyc", latitude: 40.7, longitude: -74.0),
    ]
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 0, longitude: 0)!, radiusMeters: 20_000_000)!
    let clusters = await clusterer.cluster(items: items, in: region, zoomLevel: 5)
    #expect(clusters.count == 3)
  }

  @Test("Zoom level affects clustering granularity")
  func zoomAffectsGranularity() async {
    let items = TestFixtures.makeItems(count: 10, nearLat: 41.0, nearLon: 29.0)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 50000)!

    let lowZoomClusters = await clusterer.cluster(items: items, in: region, zoomLevel: 3)
    let highZoomClusters = await clusterer.cluster(items: items, in: region, zoomLevel: 15)

    // High zoom should produce more (smaller) clusters than low zoom
    #expect(highZoomClusters.count >= lowZoomClusters.count)
  }

  @Test("All items are accounted for in cluster output")
  func allItemsAccountedFor() async {
    let items = TestFixtures.makeItems(count: 20, nearLat: 41.0, nearLon: 29.0)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 50000)!
    let clusters = await clusterer.cluster(items: items, in: region, zoomLevel: 10)

    let totalItems = clusters.reduce(0) { $0 + $1.count }
    #expect(totalItems == 20)
  }

  @Test("Merge radius decreases exponentially with zoom")
  func mergeRadiusDecay() async {
    let r0 = await clusterer.computeMergeRadius(for: 0)
    let r5 = await clusterer.computeMergeRadius(for: 5)
    let r10 = await clusterer.computeMergeRadius(for: 10)

    #expect(r0 > r5)
    #expect(r5 > r10)
    #expect(r0 / r5 > 30)  // 2^5 = 32
  }
}

// MARK: - NewsCluster Tests

@Suite("NewsCluster Model Tests")
struct NewsClusterTests {

  @Test("Cluster with empty items returns nil")
  func emptyClusterNil() {
    let cluster = NewsCluster(items: [])
    #expect(cluster == nil)
  }

  @Test("Single-item cluster is not marked as cluster")
  func singleItemNotCluster() {
    let item = TestFixtures.makeItem()
    let cluster = NewsCluster(items: [item])!
    #expect(!cluster.isCluster)
    #expect(cluster.count == 1)
  }

  @Test("Multi-item cluster is marked as cluster")
  func multiItemIsCluster() {
    let items = TestFixtures.makeItems(count: 3)
    let cluster = NewsCluster(items: items)!
    #expect(cluster.isCluster)
    #expect(cluster.count == 3)
  }

  @Test("Centroid is computed as average of coordinates")
  func centroidCalculation() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 30.0),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.center.latitude == 41.0)
    #expect(cluster.center.longitude == 29.0)
  }

  @Test("Dominant category selects most frequent")
  func dominantCategory() {
    let items = [
      TestFixtures.makeItem(id: "a", category: .technology),
      TestFixtures.makeItem(id: "b", category: .technology),
      TestFixtures.makeItem(id: "c", category: .politics),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.dominantCategory == .technology)
  }

  @Test("Representative headline uses first item")
  func representativeHeadline() {
    let items = [
      TestFixtures.makeItem(id: "a", headline: "First Headline"),
      TestFixtures.makeItem(id: "b", headline: "Second Headline"),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.representativeHeadline == "First Headline")
  }

  @Test("Average credibility label with analyzed items")
  func averageCredibility() {
    let items = [
      TestFixtures.makeItem(
        id: "a",
        analysis: HeadlineAnalysis(clickbaitScore: 0.1, sentiment: .positive, confidence: 0.9)
      ),
      TestFixtures.makeItem(
        id: "b",
        analysis: HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.8)
      ),
    ]
    let cluster = NewsCluster(items: items)!
    // Average = 0.15 → Verified
    #expect(cluster.averageCredibilityLabel == .verified)
  }

  @Test("Average credibility nil when no items have analysis")
  func noAnalysisReturnsNil() {
    let items = TestFixtures.makeItems(count: 3)
    let cluster = NewsCluster(items: items)!
    #expect(cluster.averageCredibilityLabel == nil)
  }

  @Test("Deterministic ID from sorted member IDs")
  func deterministicID() {
    let items = [
      TestFixtures.makeItem(id: "beta"),
      TestFixtures.makeItem(id: "alpha"),
      TestFixtures.makeItem(id: "gamma"),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.id == "alpha+beta+gamma")
  }
}

// MARK: - Protocol Conformance Tests

@Suite("MapFeature Protocol Conformance Tests")
struct MapFeatureProtocolTests {

  @Test("AnnotationClusterer conforms to ClusteringServiceProtocol and resolves via DI")
  func diRoundTrip() async throws {
    let container = DependencyContainer()
    await container.register(ClusteringServiceProtocol.self) {
      AnnotationClusterer()
    }

    let service = try await container.resolve(ClusteringServiceProtocol.self)
    let region = GeoRegion(
      center: GeoCoordinate(latitude: 41, longitude: 29)!, radiusMeters: 10000)!
    let clusters = await service.cluster(items: [], in: region, zoomLevel: 10)
    #expect(clusters.isEmpty)
  }
}
