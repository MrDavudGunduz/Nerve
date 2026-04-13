//
//  NewsClusterTests.swift
//  MapFeatureTests
//
//  Tests for the NewsCluster domain model — centroid computation, dominant
//  category selection, representative headline, credibility averaging,
//  and deterministic ID generation.
//

import Core
import Testing

@testable import MapFeature

@Suite("NewsCluster Model Tests")
struct NewsClusterTests {

  // MARK: Initialisation

  @Test("Cluster with empty items returns nil")
  func emptyClusterNil() {
    #expect(NewsCluster(items: []) == nil)
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

  // MARK: Centroid

  @Test("Centroid is the average of all item coordinates")
  func centroidCalculation() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 30.0),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.center.latitude == 41.0)
    #expect(cluster.center.longitude == 29.0)
  }

  // MARK: Dominant Category

  @Test("Dominant category selects the most frequent category")
  func dominantCategory() {
    let items = [
      TestFixtures.makeItem(id: "a", category: .technology),
      TestFixtures.makeItem(id: "b", category: .technology),
      TestFixtures.makeItem(id: "c", category: .politics),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.dominantCategory == .technology)
  }

  // MARK: Representative Headline

  @Test("Representative headline belongs to the item closest to centroid")
  func representativeHeadline() {
    // Centroid = avg(40+42, 28+30) = (41, 29)
    // Item "c" is exactly at the centroid → distance² = 0 → representative.
    let items = [
      TestFixtures.makeItem(id: "a", headline: "Far South-West", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", headline: "Far North-East", latitude: 42.0, longitude: 30.0),
      TestFixtures.makeItem(id: "c", headline: "At The Centroid", latitude: 41.0, longitude: 29.0),
    ]
    let cluster = NewsCluster(items: items)!
    #expect(cluster.representativeHeadline == "At The Centroid")
  }

  // MARK: Credibility

  @Test("Average credibility with all-verified scores is .verified")
  func averageCredibilityVerified() {
    let items = [
      TestFixtures.makeItem(
        id: "a",
        analysis: HeadlineAnalysis(clickbaitScore: 0.1, sentiment: .positive, confidence: 0.9)),
      TestFixtures.makeItem(
        id: "b",
        analysis: HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.8)),
    ]
    let cluster = NewsCluster(items: items)!
    // Average = 0.15 → well below 0.3 → .verified
    #expect(cluster.averageCredibilityLabel == .verified)
  }

  @Test("Average credibility is nil when no items have analysis")
  func noAnalysisReturnsNil() {
    let items = TestFixtures.makeItems(count: 3)
    let cluster = NewsCluster(items: items)!
    #expect(cluster.averageCredibilityLabel == nil)
  }

  // MARK: Deterministic ID

  @Test("Cluster ID is identical regardless of item insertion order")
  func deterministicID() {
    // SHA-256 sorts item IDs before hashing, so order must not matter.
    let itemsABC = [
      TestFixtures.makeItem(id: "alpha"),
      TestFixtures.makeItem(id: "beta"),
      TestFixtures.makeItem(id: "gamma"),
    ]
    let itemsCBA = [
      TestFixtures.makeItem(id: "gamma"),
      TestFixtures.makeItem(id: "beta"),
      TestFixtures.makeItem(id: "alpha"),
    ]
    let clusterABC = NewsCluster(items: itemsABC)!
    let clusterCBA = NewsCluster(items: itemsCBA)!
    #expect(clusterABC.id == clusterCBA.id, "Cluster ID must be order-independent")
  }
}
