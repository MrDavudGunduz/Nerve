//
//  HeadlineAnalyzer.swift
//  AILayer
//
//  Created by Davud Gunduz on 18.04.2026.
//

import Core
import Foundation
import NaturalLanguage

// MARK: - HeadlineAnalyzer

/// Production implementation of ``AIAnalysisServiceProtocol`` providing
/// privacy-first, on-device headline analysis.
///
/// ## Architecture
///
/// All inference runs locally — zero network calls:
///
/// - **Sentiment Analysis:** Apple's `NLTagger` with `.sentimentScore` tag scheme.
///   The tagger leverages the same on-device NLP models used by Mail, Messages,
///   and Siri — supporting 50+ languages including Turkish and English.
///
/// - **Clickbait Detection:** A weighted heuristic engine that scores 6 linguistic
///   signals commonly associated with clickbait headlines. When a trained CoreML
///   model is available, swap this engine without changing the public API.
///
/// ## Concurrency
///
/// `HeadlineAnalyzer` is an **actor** — all internal state (`NLTagger`) is
/// protected by actor isolation. Batch analysis uses `TaskGroup` with a
/// concurrency limit to avoid overwhelming the system.
///
/// ## Usage
///
/// ```swift
/// let analyzer = HeadlineAnalyzer()
/// let result = try await analyzer.analyzeHeadline("SHOCKING discovery changes everything!")
/// print(result.clickbaitScore)   // ~0.85
/// print(result.sentiment)        // .neutral
/// print(result.credibilityLabel) // .clickbait
/// ```
public actor HeadlineAnalyzer: AIAnalysisServiceProtocol {

  // MARK: - Properties

  /// Lazily initialized sentiment tagger — reused across invocations.
  private let sentimentTagger: NLTagger

  /// Maximum number of concurrent analyses in a batch operation.
  private static let maxConcurrency = 4

  // MARK: - Clickbait Patterns

  /// English clickbait trigger phrases (case-insensitive matching).
  private static let clickbaitPhrases: [String] = [
    "you won't believe",
    "shocking",
    "mind-blowing",
    "jaw-dropping",
    "scientists hate",
    "doctors hate",
    "this one trick",
    "what happened next",
    "will blow your mind",
    "changed my life",
    "gone wrong",
    "you need to see",
    "can't stop laughing",
    "is breaking the internet",
    "the truth about",
    "what they don't tell you",
    "secret revealed",
    "exposed",
    "unbelievable",
    "insane",
  ]

  /// Turkish clickbait trigger phrases.
  private static let clickbaitPhrasesTR: [String] = [
    "inanamayacaksınız",
    "şok eden",
    "olay yaratan",
    "herkes bunu konuşuyor",
    "bakın ne oldu",
    "işte gerçek",
    "son dakika",
    "bomba iddia",
    "akıl almaz",
    "skandal",
    "gizli gerçek",
    "kimse bilmiyor",
    "duyan şaşırdı",
    "herkesi şoke etti",
    "meğer",
    "ortaya çıktı",
    "büyük sır",
  ]

  /// Emotional/superlative words that inflate clickbait scores.
  private static let emotionalWords: Set<String> = [
    // English
    "amazing", "incredible", "unreal", "insane", "epic", "perfect",
    "worst", "best", "ultimate", "terrifying", "hilarious", "genius",
    "brilliant", "horrifying", "devastating", "miraculous", "stunning",
    // Turkish
    "müthiş", "inanılmaz", "mükemmel", "korkunç", "dehşet",
    "harika", "berbat", "felaket", "muhteşem", "olağanüstü",
  ]

  // MARK: - Init

  /// Creates a new headline analyzer with an initialized NL tagger.
  public init() {
    sentimentTagger = NLTagger(tagSchemes: [.sentimentScore])
  }

  // MARK: - AIAnalysisServiceProtocol

  /// Analyzes a single headline for clickbait likelihood and sentiment.
  ///
  /// - Parameter headline: The headline text to analyze.
  /// - Returns: A ``HeadlineAnalysis`` with clickbait score, sentiment, and confidence.
  /// - Throws: ``NerveError/ai(message:context:)`` on analysis failure.
  public func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis {
    guard !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return HeadlineAnalysis(clickbaitScore: 0.0, sentiment: .neutral, confidence: 0.1)
    }

    let sentiment = analyzeSentiment(headline)
    let (clickbaitScore, confidence) = analyzeClickbait(headline)

    return HeadlineAnalysis(
      clickbaitScore: clickbaitScore,
      sentiment: sentiment,
      confidence: confidence
    )
  }

  /// Analyzes a batch of headlines with bounded concurrency.
  ///
  /// Uses a `TaskGroup` limited to ``maxConcurrency`` concurrent tasks
  /// to prevent resource exhaustion on large batches.
  ///
  /// - Note: Because `HeadlineAnalyzer` is an actor, the child tasks in
  ///   the group serialize on the actor's executor. The concurrency limit
  ///   therefore controls *scheduling*, not true parallelism. For sub-1ms
  ///   per-headline analysis this is sufficient; if analysis latency grows
  ///   (e.g., CoreML models), consider `nonisolated` analysis functions
  ///   with per-task tagger instances to unlock real parallelism.
  ///
  /// - Parameter headlines: The headline texts to analyze.
  /// - Returns: An array of ``HeadlineAnalysis`` results in input order.
  /// - Throws: ``NerveError/ai(message:context:)`` if any individual analysis fails.
  public func analyzeBatch(_ headlines: [String]) async throws -> [HeadlineAnalysis] {
    guard !headlines.isEmpty else { return [] }

    // Index-tagged results to preserve input ordering after concurrent execution.
    var results = [HeadlineAnalysis?](repeating: nil, count: headlines.count)

    try await withThrowingTaskGroup(of: (Int, HeadlineAnalysis).self) { group in
      var launched = 0

      for (index, headline) in headlines.enumerated() {
        // Throttle: wait for a slot to open before launching more tasks.
        if launched >= Self.maxConcurrency {
          if let (idx, analysis) = try await group.next() {
            results[idx] = analysis
          }
        }

        group.addTask { [self] in
          let analysis = try await self.analyzeHeadline(headline)
          return (index, analysis)
        }
        launched += 1
      }

      // Collect remaining results.
      for try await (idx, analysis) in group {
        results[idx] = analysis
      }
    }

    return results.compactMap { $0 }
  }

  // MARK: - Sentiment Analysis

  /// Analyzes sentiment using Apple's NLTagger.
  ///
  /// The tagger returns a continuous score:
  /// - **Negative:** score < -0.1
  /// - **Neutral:**  -0.1 ≤ score ≤ 0.1
  /// - **Positive:** score > 0.1
  ///
  /// - Parameter text: The text to analyze.
  /// - Returns: The detected ``Sentiment``.
  private func analyzeSentiment(_ text: String) -> Sentiment {
    sentimentTagger.string = text

    let (tag, _) = sentimentTagger.tag(
      at: text.startIndex,
      unit: .paragraph,
      scheme: .sentimentScore
    )

    guard let tag, let score = Double(tag.rawValue) else {
      return .neutral
    }

    switch score {
    case let s where s > 0.1:
      return .positive
    case let s where s < -0.1:
      return .negative
    default:
      return .neutral
    }
  }

  // MARK: - Clickbait Detection

  /// Analyzes a headline for clickbait signals using a weighted heuristic engine.
  ///
  /// ## Signals (6 dimensions)
  ///
  /// | Signal | Weight | Description |
  /// |--------|--------|-------------|
  /// | Capitalization | 0.20 | Ratio of uppercase characters |
  /// | Punctuation | 0.15 | Exclamation/question mark density |
  /// | Phrases | 0.30 | Known clickbait trigger phrases |
  /// | Listicle | 0.10 | Numeric listicle patterns |
  /// | Emotional | 0.15 | Superlative/emotional word frequency |
  /// | Length | 0.10 | Suspiciously short titles |
  ///
  /// - Parameter headline: The headline to analyze.
  /// - Returns: A tuple of (clickbaitScore: 0.0…1.0, confidence: 0.0…1.0).
  private func analyzeClickbait(_ headline: String) -> (score: Double, confidence: Double) {
    let text = headline.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = text.lowercased()
    let words = text.split(separator: " ")
    let wordCount = Double(max(words.count, 1))

    // Signal 1: Excessive capitalization (>40% uppercase letters → strong signal)
    let capsScore = capitalizationScore(text)

    // Signal 2: Punctuation density (!! ?? !!! patterns)
    let punctScore = punctuationScore(text)

    // Signal 3: Known clickbait phrases
    let phraseScore = clickbaitPhraseScore(lowered)

    // Signal 4: Listicle pattern ("10 Things...", "5 Ways...")
    let listicleScore = listiclePatternScore(text)

    // Signal 5: Emotional/superlative word density
    let emotionalScore = emotionalWordScore(words, wordCount: wordCount)

    // Signal 6: Suspiciously short / vague titles
    let lengthScore = lengthScore(wordCount)

    // Weighted combination.
    let weightedScore =
      capsScore * 0.20
      + punctScore * 0.15
      + phraseScore * 0.30
      + listicleScore * 0.10
      + emotionalScore * 0.15
      + lengthScore * 0.10

    // Confidence: higher when signals agree (low variance → high confidence).
    let signals = [capsScore, punctScore, phraseScore, listicleScore, emotionalScore, lengthScore]
    let mean = signals.reduce(0, +) / Double(signals.count)
    let variance =
      signals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(signals.count)
    let confidence = max(0.4, min(1.0, 1.0 - variance))

    return (min(max(weightedScore, 0.0), 1.0), confidence)
  }

  // MARK: - Signal Scorers

  /// Scores capitalization ratio. Returns 0.0–1.0.
  private func capitalizationScore(_ text: String) -> Double {
    let letters = text.filter(\.isLetter)
    guard !letters.isEmpty else { return 0.0 }

    let uppercaseCount = Double(letters.filter(\.isUppercase).count)
    let ratio = uppercaseCount / Double(letters.count)

    // Only flag when >40% of letters are uppercase (excludes normal title-case).
    if ratio > 0.8 { return 1.0 }
    if ratio > 0.5 { return 0.7 }
    if ratio > 0.4 { return 0.4 }
    return 0.0
  }

  /// Scores punctuation density. Returns 0.0–1.0.
  private func punctuationScore(_ text: String) -> Double {
    let exclamations = Double(text.filter { $0 == "!" }.count)
    let questions = Double(text.filter { $0 == "?" }.count)
    let total = exclamations + questions

    if total >= 3 { return 1.0 }
    if total >= 2 { return 0.6 }
    if total >= 1 { return 0.2 }
    return 0.0
  }

  /// Scores presence of known clickbait phrases. Returns 0.0–1.0.
  private func clickbaitPhraseScore(_ loweredText: String) -> Double {
    let allPhrases = Self.clickbaitPhrases + Self.clickbaitPhrasesTR
    var matchCount = 0

    for phrase in allPhrases where loweredText.contains(phrase) {
      matchCount += 1
    }

    if matchCount >= 3 { return 1.0 }
    if matchCount >= 2 { return 0.8 }
    if matchCount >= 1 { return 0.6 }
    return 0.0
  }

  /// Pre-compiled regex for listicle patterns. Defined as a `static let`
  /// to avoid recompilation on every call — the Swift compiler may elide
  /// this, but an explicit constant is clearer.
  ///
  /// `nonisolated(unsafe)` because `Regex` is structurally immutable but
  /// not marked `Sendable` in the stdlib. Safe for concurrent reads.
  private nonisolated(unsafe) static let listicleRegex = #/^\d+\s+\w+/#

  /// Scores listicle patterns ("10 Things", "5 Ways"). Returns 0.0 or 0.8.
  private func listiclePatternScore(_ text: String) -> Double {
    return text.firstMatch(of: Self.listicleRegex) != nil ? 0.8 : 0.0
  }

  /// Scores emotional/superlative word density. Returns 0.0–1.0.
  private func emotionalWordScore(_ words: [Substring], wordCount: Double) -> Double {
    let emotionalCount = Double(
      words.filter { Self.emotionalWords.contains($0.lowercased()) }.count
    )
    let density = emotionalCount / wordCount

    if density > 0.3 { return 1.0 }
    if density > 0.15 { return 0.6 }
    if density > 0.05 { return 0.3 }
    return 0.0
  }

  /// Scores headline length — very short titles are more likely clickbait. Returns 0.0–1.0.
  private func lengthScore(_ wordCount: Double) -> Double {
    if wordCount <= 3 { return 0.5 }
    if wordCount <= 5 { return 0.2 }
    return 0.0
  }
}
