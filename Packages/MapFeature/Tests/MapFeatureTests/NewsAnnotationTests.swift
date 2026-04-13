//
//  NewsAnnotationTests.swift
//  MapFeatureTests
//
//  Tests for NewsAnnotation — reuse identifiers, coordinate mapping,
//  titles, and glyph text for single vs. cluster annotations.
//

import Core
import Testing

@testable import MapFeature

@Suite("NewsAnnotation Tests")
struct NewsAnnotationTests {

  // MARK: Reuse Identifiers

  @Test("Single-item annotation uses singleReuseID")
  func singleItemReuseID() {
    let item = TestFixtures.makeItem()
    let cluster = NewsCluster(items: [item])!
    let annotation = NewsAnnotation(cluster: cluster)
    #expect(annotation.reuseIdentifier == NewsAnnotation.singleReuseID)
  }

  @Test("Multi-item annotation uses clusterReuseID")
  func multiItemReuseID() {
    let items = TestFixtures.makeItems(count: 3)
    let cluster = NewsCluster(items: items)!
    let annotation = NewsAnnotation(cluster: cluster)
    #expect(annotation.reuseIdentifier == NewsAnnotation.clusterReuseID)
  }

  // MARK: Coordinate

  @Test("Annotation coordinate maps to cluster center")
  func annotationCoordinateMatchesCenter() {
    let items = [
      TestFixtures.makeItem(id: "a", latitude: 40.0, longitude: 28.0),
      TestFixtures.makeItem(id: "b", latitude: 42.0, longitude: 30.0),
    ]
    let cluster = NewsCluster(items: items)!
    let annotation = NewsAnnotation(cluster: cluster)
    #expect(annotation.coordinate.latitude == cluster.center.latitude)
    #expect(annotation.coordinate.longitude == cluster.center.longitude)
  }

  // MARK: Title

  @Test("Single-item annotation title is the article headline")
  func singleItemTitle() {
    let item = TestFixtures.makeItem(headline: "Breaking News")
    let cluster = NewsCluster(items: [item])!
    let annotation = NewsAnnotation(cluster: cluster)
    #expect(annotation.title == "Breaking News")
  }

  @Test("Multi-item annotation title contains the story count")
  func multiItemTitle() {
    let items = TestFixtures.makeItems(count: 5)
    let cluster = NewsCluster(items: items)!
    let annotation = NewsAnnotation(cluster: cluster)
    #expect(annotation.title?.contains("5") == true)
  }

  // MARK: Glyph Text

  @Test("glyphText is nil for single-item annotations")
  func singleItemGlyphNil() {
    let item = TestFixtures.makeItem()
    let annotation = NewsAnnotation(cluster: NewsCluster(items: [item])!)
    #expect(annotation.glyphText == nil)
  }

  @Test("glyphText contains the item count for cluster annotations")
  func clusterGlyphText() {
    let items = TestFixtures.makeItems(count: 7)
    let annotation = NewsAnnotation(cluster: NewsCluster(items: items)!)
    #expect(annotation.glyphText == "7")
  }
}
