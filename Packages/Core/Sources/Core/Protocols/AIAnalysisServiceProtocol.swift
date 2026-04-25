//
//  AIAnalysisServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for on-device AI analysis of news headlines.
///
/// The default concrete implementation in `AILayer` uses Apple's `NLTagger`
/// for sentiment analysis and a weighted heuristic engine for clickbait
/// detection — all processing runs entirely on-device with zero network calls.
/// The protocol boundary allows future replacements (e.g., CoreML models)
/// without breaking dependents.
public protocol AIAnalysisServiceProtocol: Sendable {

  /// Analyzes a single headline for clickbait likelihood and sentiment.
  ///
  /// - Parameter headline: The headline text to analyze.
  /// - Returns: A ``HeadlineAnalysis`` with scores and sentiment.
  func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis

  /// Analyzes a batch of headlines for improved throughput.
  ///
  /// - Parameter headlines: The headline texts to analyze.
  /// - Returns: An array of ``HeadlineAnalysis`` results in order.
  func analyzeBatch(_ headlines: [String]) async throws -> [HeadlineAnalysis]
}
