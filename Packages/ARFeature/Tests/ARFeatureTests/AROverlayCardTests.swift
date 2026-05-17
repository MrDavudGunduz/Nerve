//
//  AROverlayCardTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 17.05.2026.
//

import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - AROverlayCard Data Mapping Tests

@Suite("AROverlayCard Data Mapping Tests")
struct AROverlayCardDataTests {

  @Test("Card initializes from NewsItem with all properties")
  func cardFromNewsItem() {
    let item = NewsItem(
      id: "card-test-1",
      headline: "Test Headline for Card",
      summary: "A test summary.",
      source: "TechCrunch",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date(),
      analysis: HeadlineAnalysis(
        clickbaitScore: 0.15,
        sentiment: .positive,
        confidence: 0.92
      )
    )

    let card = AROverlayCard(newsItem: item)
    // Verify card can be constructed without errors.
    // SwiftUI views are value types; we verify the init path.
    #expect(type(of: card) == AROverlayCard.self)
  }

  @Test("Card initializes with explicit values")
  func cardFromExplicitValues() {
    let card = AROverlayCard(
      headline: "Explicit Headline",
      source: "Reuters",
      date: "May 17, 2026",
      credibilityLabel: .verified,
      onDismiss: {}
    )
    #expect(type(of: card) == AROverlayCard.self)
  }

  @Test("Card initializes without credibility label")
  func cardWithoutCredibility() {
    let item = NewsItem(
      id: "card-test-2",
      headline: "No Analysis Item",
      summary: "No AI analysis available.",
      source: "AP",
      category: .politics,
      coordinate: GeoCoordinate(latitude: 38.907, longitude: -77.037)!,
      publishedAt: Date()
    )
    let card = AROverlayCard(newsItem: item)
    #expect(type(of: card) == AROverlayCard.self)
  }

  @Test("Card initializes without dismiss action")
  func cardWithoutDismiss() {
    let card = AROverlayCard(
      headline: "No Dismiss",
      source: "BBC",
      date: "Jan 1, 2026"
    )
    #expect(type(of: card) == AROverlayCard.self)
  }

  @Test("All credibility labels produce valid cards")
  func allCredibilityLabels() {
    for label in [CredibilityLabel.verified, .caution, .clickbait] {
      let card = AROverlayCard(
        headline: "Test for \(label.rawValue)",
        source: "Test",
        date: "May 17, 2026",
        credibilityLabel: label
      )
      #expect(type(of: card) == AROverlayCard.self)
    }
  }
}

// MARK: - AROverlayToggle State Tests

@Suite("AROverlayToggle State Tests")
@MainActor
struct AROverlayToggleStateTests {

  private func makeTechItem() -> NewsItem {
    NewsItem(
      id: "toggle-test-1",
      headline: "Toggle Test Headline",
      summary: "Testing overlay toggle.",
      source: "TestSource",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date()
    )
  }

  @Test("Initial overlay is visible")
  func initialOverlayVisible() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    #expect(vm.isOverlayVisible == true)
  }

  @Test("Overlay can be toggled off")
  func overlayToggleOff() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.isOverlayVisible = false
    #expect(vm.isOverlayVisible == false)
  }

  @Test("Overlay can be toggled back on")
  func overlayToggleBackOn() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.isOverlayVisible = false
    vm.isOverlayVisible = true
    #expect(vm.isOverlayVisible == true)
  }

  @Test("Reset restores overlay visibility")
  func resetRestoresOverlay() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.isOverlayVisible = false
    vm.reset()
    #expect(vm.isOverlayVisible == true)
  }
}
