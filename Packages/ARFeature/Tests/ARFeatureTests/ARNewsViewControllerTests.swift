//
//  ARNewsViewControllerTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 17.05.2026.
//

import Core
import Foundation
import Testing

@testable import ARFeature

#if canImport(UIKit)

  // MARK: - ARNewsViewController Tests

  @Suite("ARNewsViewController Tests")
  @MainActor
  struct ARNewsViewControllerTests {

    private func makeTechItem() -> NewsItem {
      NewsItem(
        id: "test-vc-tech",
        headline: "AR Controller Test Headline",
        summary: "Testing UIKit integration.",
        source: "TestSource",
        category: .technology,
        coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
        publishedAt: Date()
      )
    }

    @Test("ViewController initializes with news item")
    func initializesWithNewsItem() {
      let item = makeTechItem()
      let vc = ARNewsViewController(newsItem: item)

      #expect(vc.newsItem.id == item.id)
      #expect(vc.newsItem.headline == item.headline)
    }

    @Test("ViewController prefers hidden status bar")
    func prefersHiddenStatusBar() {
      let vc = ARNewsViewController(newsItem: makeTechItem())
      #expect(vc.prefersStatusBarHidden == true)
    }

    @Test("ViewController prefers auto-hidden home indicator")
    func prefersAutoHiddenHomeIndicator() {
      let vc = ARNewsViewController(newsItem: makeTechItem())
      #expect(vc.prefersHomeIndicatorAutoHidden == true)
    }

    @Test("ViewController supports all orientations")
    func supportsAllOrientations() {
      let vc = ARNewsViewController(newsItem: makeTechItem())
      #expect(vc.supportedInterfaceOrientations == .all)
    }
  }

#endif
