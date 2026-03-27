//
//  NewsItem.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

// MARK: - NewsCategory

/// A classification category for a news item.
public enum NewsCategory: String, Sendable, Codable, CaseIterable {
  case politics
  case technology
  case science
  case health
  case sports
  case entertainment
  case business
  case environment
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
public struct NewsItem: Sendable, Codable, Hashable, Identifiable {

  /// Unique identifier for the news item.
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
}
