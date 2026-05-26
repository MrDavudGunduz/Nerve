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

  // MARK: - AR Support

  /// Mapping of categories to their associated USDZ model names.
  ///
  /// This is the **single source of truth** for AR eligibility. To make a new
  /// category AR-capable, add an entry here — no other code changes required.
  ///
  /// Model names correspond to bundled `.usdz` files (without extension)
  /// or keys in the remote asset catalog.
  private static let arModelCatalog: [NewsCategory: String] = [
    .technology: "tech_device",
    .science: "science_model",
    .health: "health_dna",
    .environment: "environment_globe",
  ]

  /// Whether this news item is eligible for AR/3D model display.
  ///
  /// Determined by the ``arModelCatalog`` — categories with an associated
  /// USDZ model are AR-capable. Expand by adding entries to the catalog.
  public var isARCapable: Bool {
    Self.arModelCatalog[category] != nil
  }

  /// The USDZ model name associated with this item's category.
  ///
  /// Returns `nil` if ``isARCapable`` is `false`.
  /// The name corresponds to a bundled `.usdz` file (without extension)
  /// or a key in the remote asset catalog.
  public var arModelName: String? {
    Self.arModelCatalog[category]
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

/// Content-aware equality: two `NewsItem`s are equal if they share the
/// same `id` **and** the same `analysis` result.
///
/// Including `analysis` ensures SwiftUI detects credibility badge updates
/// after AI enrichment — a pure ID comparison would return `true` for an
/// item before and after analysis, suppressing the UI diff.
///
/// All other fields (headline, summary, coordinate, etc.) are sourced from
/// the upstream API and never mutate for a given ID within a single session,
/// so comparing them would add cost without benefit.
extension NewsItem: Equatable {
  public static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
    lhs.id == rhs.id && lhs.analysis == rhs.analysis
  }
}

// MARK: - Hashable

/// Identity-based hashing — uses only `id` for O(1) Set/Dictionary lookup.
///
/// `Hashable` requires: if `a == b`, then `a.hashValue == b.hashValue`.
/// The reverse is NOT required. Since our `==` compares `id + analysis`,
/// hashing only `id` satisfies the contract — equal items always share an
/// `id`, so they always share a hash. Two items with the same `id` but
/// different `analysis` hash identically, which is correct (they collide
/// in the same bucket and `==` disambiguates).
extension NewsItem: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
