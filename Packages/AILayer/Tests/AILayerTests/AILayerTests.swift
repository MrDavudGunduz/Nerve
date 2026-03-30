import Core
import Foundation
import Testing

@testable import AILayer

// MARK: - Module Tests

@Suite("AILayer Module Tests")
struct AILayerModuleTests {

  @Test("AILayer module version is defined")
  func moduleVersion() {
    #expect(!AILayer.version.isEmpty)
  }
}

// MARK: - Protocol Conformance Stub

/// Compile-time verification that `AIAnalysisServiceProtocol` can be implemented.
struct StubAIAnalysisService: AIAnalysisServiceProtocol {

  func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis {
    HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.9)
  }

  func analyzeBatch(_ headlines: [String]) async throws -> [HeadlineAnalysis] {
    headlines.map { _ in
      HeadlineAnalysis(clickbaitScore: 0.2, sentiment: .neutral, confidence: 0.9)
    }
  }
}

// MARK: - DI Round-Trip Tests

@Suite("AILayer Protocol Conformance Tests")
struct AILayerProtocolTests {

  let container = DependencyContainer()

  @Test("StubAIAnalysisService conforms to AIAnalysisServiceProtocol and resolves via DI")
  func aiServiceRoundTrip() async throws {
    await container.register(AIAnalysisServiceProtocol.self) {
      StubAIAnalysisService()
    }

    let service = try await container.resolve(AIAnalysisServiceProtocol.self)
    let analysis = try await service.analyzeHeadline("Test headline")
    #expect(analysis.clickbaitScore == 0.2)
    #expect(analysis.sentiment == .neutral)
    #expect(analysis.credibilityLabel == .verified)
  }

  @Test("Batch analysis returns correct count")
  func batchAnalysis() async throws {
    let service = StubAIAnalysisService()
    let results = try await service.analyzeBatch(["A", "B", "C"])
    #expect(results.count == 3)
  }
}
