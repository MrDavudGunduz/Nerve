//
//  NewsItemPersistenceModel.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 02.04.2026.
//

import Core
import Foundation
import SwiftData

// MARK: - NewsItemPersistenceModel

/// SwiftData persistence model for a cached news article.
///
/// This is the storage-layer counterpart of ``Core/NewsItem``.
/// It is intentionally kept separate from the domain model to:
///
/// 1. Allow the schema to evolve (migrations) without changing the domain type.
/// 2. Prevent SwiftData macros and persistence concerns from leaking into `Core`.
///
/// ## Mapping
///
/// Convert to/from the domain model via the static factory methods:
///
/// ```swift
/// let model = NewsItemPersistenceModel(from: newsItem)
/// let domainItem = try model.toDomainModel()
/// ```
///
/// ## Registration
///
/// This type is registered in ``ModelRegistry/allModels`` so that
/// `ModelContainer` includes it in the SwiftData schema automatically.
@Model
public final class NewsItemPersistenceModel {

  // MARK: - Indexes (Future)

  /// Desired database indexes for spatial fetch queries and TTL pruning.
  ///
  /// SwiftData (iOS 17) does not expose a public API for declarative index
  /// creation. The framework creates implicit indexes only for
  /// `@Attribute(.unique)` properties (e.g., ``id``).
  ///
  /// When the project's minimum deployment target is raised to iOS 18+,
  /// add the following indexes using the `#Index` macro:
  ///
  /// ```swift
  /// #Index<NewsItemPersistenceModel>([\.latitude, \.longitude])
  /// #Index<NewsItemPersistenceModel>([\.publishedAt])
  /// #Index<NewsItemPersistenceModel>([\.cachedAt])
  /// ```
  ///
  /// Without explicit indexes, SwiftData performs full table scans on every
  /// region-filtered fetch — this becomes noticeable when the local
  /// store grows beyond a few hundred items.

  // MARK: - Stored Properties

  /// Unique identifier matching `NewsItem.id`.
  @Attribute(.unique)
  public var id: String

  /// The headline text.
  public var headline: String

  /// A brief summary of the article.
  ///
  /// Stored externally via `@Attribute(.externalStorage)` to keep the main
  /// SQLite row compact when summaries grow large. SwiftData transparently
  /// manages the side file and loads it on demand.
  @Attribute(.externalStorage)
  public var summary: String

  /// The publication or news source name.
  public var source: String

  /// The URL of the full article, stored as a string.
  public var articleURLString: String?

  /// Raw value of ``Core/NewsCategory``.
  public var categoryRaw: String

  /// Latitude component of the news location.
  public var latitude: Double

  /// Longitude component of the news location.
  public var longitude: Double

  /// The publication timestamp.
  public var publishedAt: Date

  /// Optional URL to a thumbnail image, stored as a string.
  public var imageURLString: String?

  /// The cached date when this record was last fetched from the network.
  public var cachedAt: Date

  // MARK: - AI Analysis Fields

  /// Clickbait score produced by the on-device AI model (0.0 genuine → 1.0 clickbait).
  /// `nil` if analysis has not been run yet.
  public var clickbaitScore: Double?

  /// Raw value of ``Core/Sentiment`` (e.g. "positive", "neutral", "negative").
  public var sentimentRaw: String?

  /// The model's confidence level for the analysis result (0.0 … 1.0).
  public var analysisConfidence: Double?

  // MARK: - Init

  /// Creates a persistence model from the given domain model.
  ///
  /// - Parameter item: The domain `NewsItem` to persist.
  public init(from item: NewsItem) {
    self.id = item.id
    self.headline = item.headline
    self.summary = item.summary
    self.source = item.source
    self.articleURLString = item.articleURL?.absoluteString
    self.categoryRaw = item.category.rawValue
    self.latitude = item.coordinate.latitude
    self.longitude = item.coordinate.longitude
    self.publishedAt = item.publishedAt
    self.imageURLString = item.imageURL?.absoluteString
    self.cachedAt = Date()
    // AI analysis — persisted when available; nil when Phase 3 is incomplete.
    self.clickbaitScore = item.analysis?.clickbaitScore
    self.sentimentRaw = item.analysis?.sentiment.rawValue
    self.analysisConfidence = item.analysis?.confidence
  }

  // MARK: - Domain Conversion

  /// Converts this persistence model back to the canonical domain type.
  ///
  /// - Returns: A ``Core/NewsItem`` populated from stored fields.
  /// - Throws: ``Core/NerveError`` if stored data is invalid
  ///   (e.g., out-of-range coordinate or unknown category).
  public func toDomainModel() throws -> NewsItem {
    guard let coordinate = GeoCoordinate(latitude: latitude, longitude: longitude) else {
      throw NerveError.storage(
        message: "Persisted coordinate is invalid: (\(latitude), \(longitude)) for item '\(id)'."
      )
    }

    guard let category = NewsCategory(rawValue: categoryRaw) else {
      throw NerveError.storage(
        message: "Unknown category '\(categoryRaw)' for item '\(id)'."
      )
    }

    // Reconstruct HeadlineAnalysis if all three fields are present.
    let analysis: HeadlineAnalysis?
    if let score = clickbaitScore,
      let sentimentStr = sentimentRaw,
      let sentiment = Sentiment(rawValue: sentimentStr),
      let confidence = analysisConfidence
    {
      analysis = HeadlineAnalysis(
        clickbaitScore: score, sentiment: sentiment, confidence: confidence)
    } else {
      analysis = nil
    }

    return NewsItem(
      id: id,
      headline: headline,
      summary: summary,
      source: source,
      articleURL: articleURLString.flatMap(URL.init(string:)),
      category: category,
      coordinate: coordinate,
      publishedAt: publishedAt,
      imageURL: imageURLString.flatMap(URL.init(string:)),
      analysis: analysis
    )
  }
}
