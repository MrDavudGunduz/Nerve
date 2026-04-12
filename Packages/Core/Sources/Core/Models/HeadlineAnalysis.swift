//
//  HeadlineAnalysis.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

// MARK: - Sentiment

/// The emotional tone detected in a news headline.
public enum Sentiment: String, Sendable, Codable, CaseIterable {
  case positive
  case neutral
  case negative
}

// MARK: - HeadlineAnalysis

/// The result of on-device AI analysis of a single news headline.
///
/// Produced by ``AIAnalysisServiceProtocol`` and persisted alongside
/// the corresponding ``NewsItem`` in the local store.
public struct HeadlineAnalysis: Sendable, Codable, Hashable {

  /// A score from 0.0 (genuine) to 1.0 (clickbait).
  public let clickbaitScore: Double

  /// The dominant sentiment of the headline.
  public let sentiment: Sentiment

  /// The model's confidence in its analysis (0.0 … 1.0).
  public let confidence: Double

  /// Creates a headline analysis with the given scores.
  ///
  /// Values outside the valid range are clamped to 0.0 … 1.0
  /// to prevent invalid ML outputs from propagating through the system.
  public init(clickbaitScore: Double, sentiment: Sentiment, confidence: Double) {
    self.clickbaitScore = min(max(clickbaitScore, 0.0), 1.0)
    self.sentiment = sentiment
    self.confidence = min(max(confidence, 0.0), 1.0)
  }

  /// A human-readable credibility label derived from the clickbait score.
  ///
  /// Delegates to the static ``credibilityLabel(for:)`` helper so that
  /// any consumer (e.g. ``NewsCluster``) can compute a label for an
  /// arbitrary score without constructing a full `HeadlineAnalysis`.
  public var credibilityLabel: CredibilityLabel {
    Self.credibilityLabel(for: clickbaitScore)
  }

  /// Computes the credibility label for a given clickbait score.
  ///
  /// This is the **single source of truth** for all threshold logic.
  /// Both ``credibilityLabel`` and ``NewsCluster/averageCredibilityLabel``
  /// delegate here so that boundary changes only need to be made once.
  ///
  /// - Parameter score: A clickbait score in the range 0.0 … 1.0.
  /// - Returns: The corresponding ``CredibilityLabel``.
  public static func credibilityLabel(for score: Double) -> CredibilityLabel {
    switch score {
    case ..<0.3: return .verified
    case 0.3..<0.7: return .caution
    default: return .clickbait
    }
  }
}

// MARK: - CredibilityLabel

/// A user-facing label indicating the trustworthiness of a headline.
public enum CredibilityLabel: String, Sendable, Codable {
  /// Clickbait score < 0.3 — likely genuine content.
  case verified = "Verified"
  /// Clickbait score 0.3–0.7 — needs reader judgment.
  case caution = "Caution"
  /// Clickbait score > 0.7 — likely clickbait.
  case clickbait = "Clickbait"
}
