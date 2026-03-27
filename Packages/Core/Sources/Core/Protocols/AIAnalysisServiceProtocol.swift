//
//  AIAnalysisServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for on-device AI analysis of news headlines.
///
/// Concrete implementations use CoreML in `AILayer` for clickbait
/// detection and sentiment scoring on the Neural Processing Unit.
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
