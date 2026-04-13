//
//  CredibilityColorTests.swift
//  MapFeatureTests
//
//  Tests for credibility and category colour logic in ClusterAnnotationView.
//  Validates that the colour system correctly signals trust/caution/clickbait
//  and that each NewsCategory has a unique theme colour.
//

import Core
import Testing
import UIKit

@testable import MapFeature

@Suite("Credibility Color Tests")
struct CredibilityColorTests {

  // MARK: Credibility Label Colours

  @Test("credibilityColor returns distinct colours for all labels")
  func distinctColors() {
    let verified = ClusterAnnotationView.credibilityColor(for: .verified)
    let caution = ClusterAnnotationView.credibilityColor(for: .caution)
    let clickbait = ClusterAnnotationView.credibilityColor(for: .clickbait)

    #expect(verified != caution)
    #expect(caution != clickbait)
    #expect(verified != clickbait)
  }

  @Test("credibilityColor for verified has dominant green channel")
  func verifiedIsGreen() {
    let color = ClusterAnnotationView.credibilityColor(for: .verified)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    // Green must dominate to correctly signal trustworthiness.
    #expect(g > r, "Green channel should dominate for .verified")
    #expect(g > b, "Green channel should dominate for .verified")
  }

  @Test("credibilityColor for clickbait has dominant red channel")
  func clickbaitIsRed() {
    let color = ClusterAnnotationView.credibilityColor(for: .clickbait)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    // Red must dominate to correctly signal danger/clickbait.
    #expect(r > g, "Red channel should dominate for .clickbait")
    #expect(r > b, "Red channel should dominate for .clickbait")
  }

  // MARK: Category Colours

  @Test("color(for:) returns a distinct colour for every NewsCategory")
  func categoryColorsAreDistinct() {
    let colors = NewsCategory.allCases.map { ClusterAnnotationView.color(for: $0) }
    let uniqueCount = Set(colors.map { "\($0.cgColor.components ?? [])" }).count
    #expect(
      uniqueCount == NewsCategory.allCases.count,
      "Every category must have a unique theme color")
  }

  // MARK: Cluster Credibility Averaging

  @Test("averageCredibilityLabel is .verified for all-low-score items")
  func clusterCredibilityVerified() {
    let items = [
      TestFixtures.makeItem(
        id: "a",
        analysis: HeadlineAnalysis(clickbaitScore: 0.05, sentiment: .positive, confidence: 0.95)),
      TestFixtures.makeItem(
        id: "b",
        analysis: HeadlineAnalysis(clickbaitScore: 0.10, sentiment: .neutral, confidence: 0.90)),
    ]
    let cluster = NewsCluster(items: items)!
    // avg = 0.075 → below 0.3 → .verified
    #expect(cluster.averageCredibilityLabel == .verified)
  }

  @Test("averageCredibilityLabel is .clickbait for all-high-score items")
  func clusterCredibilityClickbait() {
    let items = [
      TestFixtures.makeItem(
        id: "a",
        analysis: HeadlineAnalysis(clickbaitScore: 0.85, sentiment: .negative, confidence: 0.70)),
      TestFixtures.makeItem(
        id: "b",
        analysis: HeadlineAnalysis(clickbaitScore: 0.90, sentiment: .negative, confidence: 0.80)),
    ]
    let cluster = NewsCluster(items: items)!
    // avg = 0.875 → above 0.7 → .clickbait
    #expect(cluster.averageCredibilityLabel == .clickbait)
  }

  @Test("averageCredibilityLabel is nil when no item has analysis")
  func credibilityNilWithoutAnalysis() {
    let items = TestFixtures.makeItems(count: 3)
    let cluster = NewsCluster(items: items)!
    #expect(cluster.averageCredibilityLabel == nil)
  }

  @Test("Partial analysis — only analysed items contribute to the average")
  func partialAnalysis() {
    let items = [
      TestFixtures.makeItem(
        id: "a",
        analysis: HeadlineAnalysis(clickbaitScore: 0.1, sentiment: .positive, confidence: 0.9)),
      TestFixtures.makeItem(id: "b"),  // no analysis — must be excluded
    ]
    let cluster = NewsCluster(items: items)!
    // Only item "a" contributes → avg = 0.1 → .verified
    #expect(cluster.averageCredibilityLabel == .verified)
  }
}
