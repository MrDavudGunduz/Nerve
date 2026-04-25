//
//  NewsItem.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

// MARK: - NewsCategory

/// The topic classification for a news item.
///
/// Used throughout Nerve to:
/// - Select the category color and SF Symbol on map annotations.
/// - Determine the ``NewsCluster/dominantCategory`` for cluster bubbles.
/// - Filter or group news in list and search views.
///
/// The `rawValue` is the persisted string in SwiftData
/// and must not be changed without a migration.
public enum NewsCategory: String, Sendable, Codable, CaseIterable {
  /// Government, elections, legislation, and international relations.
  case politics
  /// Software, hardware, AI, and digital innovation.
  case technology
  /// Research, discovery, engineering, and natural sciences.
  case science
  /// Medicine, public health, fitness, and mental wellness.
  case health
  /// Professional and amateur sports events and athlete news.
  case sports
  /// Film, music, television, gaming, and celebrity culture.
  case entertainment
  /// Markets, economics, corporate news, and personal finance.
  case business
  /// Climate, nature, conservation, and sustainability.
  case environment
  /// Stories that don't fit a primary category.
  case other
}

// MARK: - NewsItem

/// The canonical domain model for a news article throughout Nerve.
///
/// `NewsItem` is defined in `Core` so that every module (Network, Storage,
/// Map, AI) can reference the same type without introducing cross-module
/// coupling beyond `Core`.
///
/// - Note: This is a **domain transfer object**, not a persistence model.
///   `StorageLayer` defines its own `@Model` schema that maps to/from this type.
public struct NewsItem: Sendable, Codable, Identifiable {

  /// Unique identifier for the news item, sourced from the upstream API.
  ///
  /// Kept as `String` rather than `UUID` because:
  /// - IDs originate from an external REST API (format is not guaranteed to be UUID v4).
  /// - String IDs round-trip through `Codable`, `@Attribute(.unique)`, and MapKit
  ///   annotation reuse without any conversion overhead.
  ///
  /// If Nerve ever generates items locally (e.g., from on-device analysis),
  /// use `UUID().uuidString` at creation time to ensure global uniqueness.
  public let id: String

  /// The headline text.
  public let headline: String

  /// A brief summary of the article.
  public let summary: String

  /// The publication or news source name.
  public let source: String

  /// The URL of the full article.
  public let articleURL: URL?

  /// The category classification.
  public let category: NewsCategory

  /// The geographic location associated with the news.
  public let coordinate: GeoCoordinate

  /// The publication timestamp.
  public let publishedAt: Date

  /// Optional URL to a thumbnail image.
  public let imageURL: URL?

  /// AI-generated analysis result, if available.
  public let analysis: HeadlineAnalysis?

  /// Creates a new `NewsItem`.
  public init(
    id: String,
    headline: String,
    summary: String,
    source: String,
    articleURL: URL? = nil,
    category: NewsCategory,
    coordinate: GeoCoordinate,
    publishedAt: Date,
    imageURL: URL? = nil,
    analysis: HeadlineAnalysis? = nil
  ) {
    self.id = id
    self.headline = headline
    self.summary = summary
    self.source = source
    self.articleURL = articleURL
    self.category = category
    self.coordinate = coordinate
    self.publishedAt = publishedAt
    self.imageURL = imageURL
    self.analysis = analysis
  }

  // MARK: - Convenience

  /// Returns a copy of this item with the given analysis attached.
  ///
  /// Use this instead of manually reconstructing a `NewsItem` after AI
  /// enrichment — it is resilient to future property additions.
  ///
  /// ```swift
  /// let enriched = item.withAnalysis(headlineAnalysis)
  /// ```
  public func withAnalysis(_ analysis: HeadlineAnalysis) -> NewsItem {
    NewsItem(
      id: id,
      headline: headline,
      summary: summary,
      source: source,
      articleURL: articleURL,
      category: category,
      coordinate: coordinate,
      publishedAt: publishedAt,
      imageURL: imageURL,
      analysis: analysis
    )
  }
}

// MARK: - Equatable

/// Identity-based equality: two `NewsItem`s are equal if they share the same `id`.
///
/// This prevents unnecessary UI diffing (e.g., annotation re-rendering in MapKit)
/// when only the `analysis` result changes after AI enrichment. Auto-synthesized
/// `Equatable` would compare *all* properties, causing spurious inequality.
extension NewsItem: Equatable {
  public static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Hashable

/// Identity-based hashing consistent with the custom `Equatable` above.
extension NewsItem: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
