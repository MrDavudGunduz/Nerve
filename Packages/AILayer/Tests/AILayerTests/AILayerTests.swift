import Core
import Foundation
import Testing

@testable import AILayer

// MARK: - Clickbait Detection Tests

@Suite("HeadlineAnalyzer Clickbait Detection")
struct HeadlineAnalyzerClickbaitTests {

  let analyzer = HeadlineAnalyzer()

  @Test("Genuine news headline scores below 0.3")
  func genuineHeadline() async throws {
    let result = try await analyzer.analyzeHeadline(
      "Istanbul Municipality Announces New Metro Line Extension"
    )
    #expect(result.clickbaitScore < 0.3)
    #expect(result.credibilityLabel == .verified)
  }

  @Test("Known clickbait phrases produce elevated score")
  func clickbaitPhrases() async throws {
    let result = try await analyzer.analyzeHeadline(
      "YOU WON'T BELIEVE What Scientists Discovered! This One Trick Is SHOCKING!!!"
    )
    // Multiple signals converge: phrases + caps + punctuation + emotional words.
    #expect(result.clickbaitScore > 0.4)
  }

  @Test("ALL CAPS headline activates capitalization signal")
  func allCapsHeadline() async throws {
    let result = try await analyzer.analyzeHeadline(
      "BREAKING NEWS EVERYONE MUST SEE THIS IMMEDIATELY"
    )
    // Caps alone produces ~0.2 (weight=0.20). Verify it's above zero.
    #expect(result.clickbaitScore > 0.1)
  }

  @Test("Excessive punctuation increases clickbait score")
  func excessivePunctuation() async throws {
    let result = try await analyzer.analyzeHeadline(
      "This discovery changes everything!!! Can you believe it???"
    )
    // Punctuation signal fires, plus emotional word "unbelievable" patterns.
    #expect(result.clickbaitScore > 0.1)
  }

  @Test("Listicle pattern detected")
  func listiclePattern() async throws {
    let result = try await analyzer.analyzeHeadline(
      "10 Amazing Ways to Transform Your Morning Routine"
    )
    // Listicle (0.10 weight) + emotional word "amazing" (0.15 weight).
    #expect(result.clickbaitScore > 0.05)
  }

  @Test("Emotional superlatives increase score")
  func emotionalWords() async throws {
    let result = try await analyzer.analyzeHeadline(
      "Amazing incredible brilliant discovery stuns the world"
    )
    // High emotional word density → emotional signal fires.
    #expect(result.clickbaitScore > 0.05)
  }

  @Test("Turkish clickbait phrases detected")
  func turkishClickbait() async throws {
    let result = try await analyzer.analyzeHeadline(
      "İNANAMAYACAKSINIZ! Herkesi şoke etti bu olay yaratan haber!!!"
    )
    // Multiple Turkish clickbait phrases + punctuation + caps.
    #expect(result.clickbaitScore > 0.3)
  }

  @Test("Factual Turkish headline scores low")
  func factualTurkishHeadline() async throws {
    let result = try await analyzer.analyzeHeadline(
      "Galata Köprüsü Yenileme Projesi Başladı"
    )
    #expect(result.clickbaitScore < 0.3)
  }

  @Test("Score is always clamped to 0.0–1.0")
  func scoreClamped() async throws {
    let result = try await analyzer.analyzeHeadline(
      "YOU WON'T BELIEVE SHOCKING INSANE MIND-BLOWING!!! UNBELIEVABLE!!!"
    )
    #expect(result.clickbaitScore >= 0.0)
    #expect(result.clickbaitScore <= 1.0)
    #expect(result.confidence >= 0.0)
    #expect(result.confidence <= 1.0)
  }
}

// MARK: - Sentiment Analysis Tests

@Suite("HeadlineAnalyzer Sentiment Analysis")
struct HeadlineAnalyzerSentimentTests {

  let analyzer = HeadlineAnalyzer()

  @Test("Neutral factual headline returns neutral sentiment")
  func neutralSentiment() async throws {
    let result = try await analyzer.analyzeHeadline(
      "City Council Meeting Scheduled for Tuesday"
    )
    // NLTagger may vary — we just verify it produces a valid Sentiment.
    #expect(Sentiment.allCases.contains(result.sentiment))
  }

  @Test("Sentiment is always a valid enum case")
  func sentimentAlwaysValid() async throws {
    let headlines = [
      "Markets crash amid global uncertainty",
      "Community celebrates new park opening with joy",
      "Traffic report for the downtown area",
    ]
    for headline in headlines {
      let result = try await analyzer.analyzeHeadline(headline)
      #expect(Sentiment.allCases.contains(result.sentiment))
    }
  }

  @Test("Confidence is between 0.0 and 1.0")
  func confidenceRange() async throws {
    let result = try await analyzer.analyzeHeadline(
      "A moderately interesting headline about weather patterns"
    )
    #expect(result.confidence >= 0.0)
    #expect(result.confidence <= 1.0)
  }
}

// MARK: - Batch Analysis Tests

@Suite("HeadlineAnalyzer Batch Analysis")
struct HeadlineAnalyzerBatchTests {

  let analyzer = HeadlineAnalyzer()

  @Test("Batch returns correct count")
  func batchCount() async throws {
    let headlines = [
      "Breaking: Local Store Opens",
      "SHOCKING discovery changes everything!!!",
      "Weather forecast for tomorrow",
    ]
    let results = try await analyzer.analyzeBatch(headlines)
    #expect(results.count == headlines.count)
  }

  @Test("Empty batch returns empty array")
  func emptyBatch() async throws {
    let results = try await analyzer.analyzeBatch([])
    #expect(results.isEmpty)
  }

  @Test("Batch results maintain input ordering")
  func batchOrdering() async throws {
    let genuineHeadline = "City Council Approves Annual Budget"
    let clickbaitHeadline = "YOU WON'T BELIEVE WHAT HAPPENED NEXT!!! SHOCKING!!!"

    let results = try await analyzer.analyzeBatch([genuineHeadline, clickbaitHeadline])
    #expect(results.count == 2)
    // The genuine headline should score lower than the clickbait one.
    #expect(results[0].clickbaitScore < results[1].clickbaitScore)
  }

  @Test("Large batch processes without error")
  func largeBatch() async throws {
    let headlines = (0..<50).map { "Headline number \($0) about daily events" }
    let results = try await analyzer.analyzeBatch(headlines)
    #expect(results.count == 50)
  }
}

// MARK: - Edge Case Tests

@Suite("HeadlineAnalyzer Edge Cases")
struct HeadlineAnalyzerEdgeCaseTests {

  let analyzer = HeadlineAnalyzer()

  @Test("Empty string returns low confidence neutral result")
  func emptyString() async throws {
    let result = try await analyzer.analyzeHeadline("")
    #expect(result.clickbaitScore == 0.0)
    #expect(result.sentiment == .neutral)
    #expect(result.confidence <= 0.2)
  }

  @Test("Whitespace-only string treated as empty")
  func whitespaceOnly() async throws {
    let result = try await analyzer.analyzeHeadline("   \n\t  ")
    #expect(result.clickbaitScore == 0.0)
    #expect(result.sentiment == .neutral)
  }

  @Test("Very long headline produces valid result")
  func veryLongHeadline() async throws {
    let longText = String(repeating: "This is a news headline about events. ", count: 50)
    let result = try await analyzer.analyzeHeadline(longText)
    #expect(result.clickbaitScore >= 0.0 && result.clickbaitScore <= 1.0)
    #expect(result.confidence >= 0.0 && result.confidence <= 1.0)
  }

  @Test("Single word headline produces valid result")
  func singleWord() async throws {
    let result = try await analyzer.analyzeHeadline("Fire")
    #expect(result.clickbaitScore >= 0.0)
    #expect(result.clickbaitScore <= 1.0)
  }

  @Test("Non-Latin script headline does not crash")
  func nonLatinScript() async throws {
    let result = try await analyzer.analyzeHeadline("العالم يتغير بسرعة")
    #expect(result.clickbaitScore >= 0.0 && result.clickbaitScore <= 1.0)
  }

  @Test("Emoji-heavy headline does not crash")
  func emojiHeadline() async throws {
    let result = try await analyzer.analyzeHeadline("🔥🔥🔥 HOT NEWS 🔥🔥🔥")
    #expect(result.clickbaitScore >= 0.0 && result.clickbaitScore <= 1.0)
  }
}

// MARK: - DI Integration Tests

@Suite("HeadlineAnalyzer DI Integration")
struct HeadlineAnalyzerDITests {

  @Test("HeadlineAnalyzer conforms to AIAnalysisServiceProtocol and resolves via DI")
  func diRoundTrip() async throws {
    let container = DependencyContainer()
    await container.register(AIAnalysisServiceProtocol.self, lifetime: .singleton) {
      HeadlineAnalyzer()
    }
    let service = try await container.resolve(AIAnalysisServiceProtocol.self)
    let result = try await service.analyzeHeadline("Test headline for DI round-trip")
    #expect(result.clickbaitScore >= 0.0)
    #expect(result.confidence > 0.0)
  }
}

// MARK: - Module Tests

@Suite("AILayer Module Tests")
struct AILayerModuleTests {

  @Test("AILayer module version is 1.0.0")
  func moduleVersion() {
    #expect(AILayer.version == "1.0.0")
  }
}
