//
//  PersistenceModelTests.swift
//  StorageLayerTests
//
//  Created by Davud Gunduz on 17.05.2026.
//

import Core
import Foundation
import SwiftData
import Testing

@testable import StorageLayer

// MARK: - NewsItemPersistenceModel Tests

/// Tests for the ``NewsItemPersistenceModel`` ↔ ``NewsItem`` conversion
/// and SwiftData schema integration.
struct PersistenceModelTests {

  // MARK: - Helpers

  /// Creates a test `NewsItem` with overrideable properties.
  private static func makeItem(
    id: String = "test-item-1",
    headline: String = "Test Headline",
    category: NewsCategory = .technology,
    latitude: Double = 41.0,
    longitude: Double = 29.0,
    analysis: HeadlineAnalysis? = nil
  ) -> NewsItem {
    NewsItem(
      id: id,
      headline: headline,
      summary: "Test summary text",
      source: "Test Source",
      articleURL: URL(string: "https://example.com/article"),
      category: category,
      coordinate: GeoCoordinate(latitude: latitude, longitude: longitude)!,
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      imageURL: URL(string: "https://example.com/image.jpg"),
      analysis: analysis
    )
  }

  // MARK: - Domain → Persistence

  @Test("Persistence model preserves all fields from domain model")
  func domainToPersistence() {
    let item = Self.makeItem()
    let model = NewsItemPersistenceModel(from: item)

    #expect(model.id == "test-item-1")
    #expect(model.headline == "Test Headline")
    #expect(model.summary == "Test summary text")
    #expect(model.source == "Test Source")
    #expect(model.articleURLString == "https://example.com/article")
    #expect(model.categoryRaw == "technology")
    #expect(model.latitude == 41.0)
    #expect(model.longitude == 29.0)
    #expect(model.imageURLString == "https://example.com/image.jpg")
    #expect(model.clickbaitScore == nil)
    #expect(model.sentimentRaw == nil)
    #expect(model.analysisConfidence == nil)
  }

  @Test("Persistence model preserves AI analysis fields")
  func domainWithAnalysisToPersistence() {
    let analysis = HeadlineAnalysis(
      clickbaitScore: 0.75,
      sentiment: .negative,
      confidence: 0.9
    )
    let item = Self.makeItem(analysis: analysis)
    let model = NewsItemPersistenceModel(from: item)

    #expect(model.clickbaitScore == 0.75)
    #expect(model.sentimentRaw == "negative")
    #expect(model.analysisConfidence == 0.9)
  }

  // MARK: - Persistence → Domain

  @Test("toDomainModel round-trips correctly")
  func persistenceToDomain() throws {
    let original = Self.makeItem()
    let model = NewsItemPersistenceModel(from: original)
    let restored = try model.toDomainModel()

    #expect(restored.id == original.id)
    #expect(restored.headline == original.headline)
    #expect(restored.summary == original.summary)
    #expect(restored.source == original.source)
    #expect(restored.articleURL == original.articleURL)
    #expect(restored.category == original.category)
    #expect(restored.coordinate.latitude == original.coordinate.latitude)
    #expect(restored.coordinate.longitude == original.coordinate.longitude)
    #expect(restored.imageURL == original.imageURL)
  }

  @Test("toDomainModel reconstructs HeadlineAnalysis from stored fields")
  func persistenceWithAnalysisToDomain() throws {
    let analysis = HeadlineAnalysis(
      clickbaitScore: 0.4,
      sentiment: .positive,
      confidence: 0.85
    )
    let item = Self.makeItem(analysis: analysis)
    let model = NewsItemPersistenceModel(from: item)
    let restored = try model.toDomainModel()

    #expect(restored.analysis != nil)
    #expect(restored.analysis?.clickbaitScore == 0.4)
    #expect(restored.analysis?.sentiment == .positive)
    #expect(restored.analysis?.confidence == 0.85)
  }

  @Test("toDomainModel returns nil analysis when fields are partial")
  func partialAnalysisFieldsYieldNilAnalysis() throws {
    let item = Self.makeItem()
    let model = NewsItemPersistenceModel(from: item)
    // Simulate partial data: only clickbaitScore set, missing sentiment/confidence.
    model.clickbaitScore = 0.5
    model.sentimentRaw = nil
    model.analysisConfidence = nil

    let restored = try model.toDomainModel()
    #expect(restored.analysis == nil)
  }

  // MARK: - Defensive Fallbacks

  @Test("Unknown category raw value falls back to .other")
  func unknownCategoryFallback() throws {
    let item = Self.makeItem()
    let model = NewsItemPersistenceModel(from: item)
    model.categoryRaw = "future_unknown_category"

    let restored = try model.toDomainModel()
    #expect(restored.category == .other)
  }

  @Test("Invalid coordinates throw NerveError.storage")
  func invalidCoordinatesThrow() {
    let item = Self.makeItem()
    let model = NewsItemPersistenceModel(from: item)
    model.latitude = 999.0  // Invalid

    #expect(throws: NerveError.self) {
      _ = try model.toDomainModel()
    }
  }

  @Test("Nil URL strings produce nil domain URL properties")
  func nilURLStrings() throws {
    let item = Self.makeItem()
    let model = NewsItemPersistenceModel(from: item)
    model.articleURLString = nil
    model.imageURLString = nil

    let restored = try model.toDomainModel()
    #expect(restored.articleURL == nil)
    #expect(restored.imageURL == nil)
  }
}

// MARK: - CachedAt Timestamp Tests

struct CachedAtTimestampTests {

  private static func makeItem() -> NewsItem {
    NewsItem(
      id: "timestamp-test",
      headline: "Timestamp Test",
      summary: "Summary",
      source: "Source",
      category: .science,
      coordinate: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
  }

  @Test("cachedAt is set to current time on init")
  func cachedAtIsRecent() {
    let before = Date()
    let model = NewsItemPersistenceModel(from: Self.makeItem())
    let after = Date()

    #expect(model.cachedAt >= before)
    #expect(model.cachedAt <= after)
  }
}
