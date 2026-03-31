import Foundation
import Testing

@testable import Core

@Suite("Domain Model Tests")
struct DomainModelTests {

  @Test("NewsItem is correctly initialized with all fields")
  func newsItemInit() {
    let coordinate = GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!
    let item = NewsItem(
      id: "test-1",
      headline: "Breaking News",
      summary: "A test summary",
      source: "Test Source",
      category: .technology,
      coordinate: coordinate,
      publishedAt: Date(timeIntervalSince1970: 0)
    )

    #expect(item.id == "test-1")
    #expect(item.headline == "Breaking News")
    #expect(item.category == .technology)
    #expect(item.coordinate == coordinate)
    #expect(item.analysis == nil)
  }

  @Test("HeadlineAnalysis credibility label boundaries")
  func credibilityLabels() {
    let verified = HeadlineAnalysis(
      clickbaitScore: 0.1, sentiment: .neutral, confidence: 0.9
    )
    #expect(verified.credibilityLabel == .verified)

    let caution = HeadlineAnalysis(
      clickbaitScore: 0.5, sentiment: .neutral, confidence: 0.8
    )
    #expect(caution.credibilityLabel == .caution)

    let clickbait = HeadlineAnalysis(
      clickbaitScore: 0.85, sentiment: .negative, confidence: 0.95
    )
    #expect(clickbait.credibilityLabel == .clickbait)
  }

  // MARK: - GeoCoordinate

  @Test("GeoRegion equality")
  func geoRegionEquality() {
    let region1 = GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 1000
    )!
    let region2 = GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 1000
    )!

    #expect(region1 == region2)
  }

  @Test("GeoCoordinate accepts valid boundary values")
  func coordinateBoundaryValues() {
    #expect(GeoCoordinate(latitude: 90, longitude: 180) != nil)
    #expect(GeoCoordinate(latitude: -90, longitude: -180) != nil)
    #expect(GeoCoordinate(latitude: 0, longitude: 0) != nil)
  }

  @Test("GeoCoordinate rejects invalid latitude")
  func coordinateInvalidLatitude() {
    #expect(GeoCoordinate(latitude: 91, longitude: 0) == nil)
    #expect(GeoCoordinate(latitude: -91, longitude: 0) == nil)
  }

  @Test("GeoCoordinate rejects invalid longitude")
  func coordinateInvalidLongitude() {
    #expect(GeoCoordinate(latitude: 0, longitude: 181) == nil)
    #expect(GeoCoordinate(latitude: 0, longitude: -181) == nil)
  }

  // MARK: - GeoRegion

  @Test("GeoRegion rejects negative radius")
  func regionNegativeRadius() {
    let center = GeoCoordinate(latitude: 41.0, longitude: 29.0)!
    #expect(GeoRegion(center: center, radiusMeters: -1) == nil)
  }

  @Test("GeoRegion accepts zero radius")
  func regionZeroRadius() {
    let center = GeoCoordinate(latitude: 41.0, longitude: 29.0)!
    #expect(GeoRegion(center: center, radiusMeters: 0) != nil)
  }

  // MARK: - Enums

  @Test("NewsCategory has expected case count")
  func newsCategoryCases() {
    #expect(NewsCategory.allCases.count == 9)
  }

  @Test("Sentiment has all expected cases")
  func sentimentCases() {
    #expect(Sentiment.allCases.count == 3)
    #expect(Sentiment.allCases.contains(.positive))
    #expect(Sentiment.allCases.contains(.neutral))
    #expect(Sentiment.allCases.contains(.negative))
  }

  // MARK: - HeadlineAnalysis Clamping

  @Test("HeadlineAnalysis clamps negative clickbaitScore to 0.0")
  func clampNegativeClickbait() {
    let analysis = HeadlineAnalysis(
      clickbaitScore: -0.5, sentiment: .neutral, confidence: 0.8
    )
    #expect(analysis.clickbaitScore == 0.0)
  }

  @Test("HeadlineAnalysis clamps clickbaitScore above 1.0 to 1.0")
  func clampHighClickbait() {
    let analysis = HeadlineAnalysis(
      clickbaitScore: 1.5, sentiment: .neutral, confidence: 0.8
    )
    #expect(analysis.clickbaitScore == 1.0)
  }

  @Test("HeadlineAnalysis clamps negative confidence to 0.0")
  func clampNegativeConfidence() {
    let analysis = HeadlineAnalysis(
      clickbaitScore: 0.5, sentiment: .positive, confidence: -0.3
    )
    #expect(analysis.confidence == 0.0)
  }

  @Test("HeadlineAnalysis clamps confidence above 1.0 to 1.0")
  func clampHighConfidence() {
    let analysis = HeadlineAnalysis(
      clickbaitScore: 0.5, sentiment: .positive, confidence: 2.0
    )
    #expect(analysis.confidence == 1.0)
  }

  // MARK: - NewsItem Codable Round-Trip

  @Test("NewsItem survives Codable encode/decode round-trip")
  func newsItemCodableRoundTrip() throws {
    let coordinate = GeoCoordinate(latitude: 41.0082, longitude: 28.9784)!
    let original = NewsItem(
      id: "codable-1",
      headline: "Test Headline",
      summary: "A summary",
      source: "TestSource",
      articleURL: URL(string: "https://example.com/article"),
      category: .technology,
      coordinate: coordinate,
      publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      imageURL: URL(string: "https://example.com/image.jpg"),
      analysis: HeadlineAnalysis(
        clickbaitScore: 0.2, sentiment: .positive, confidence: 0.95
      )
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)
    let decoded = try JSONDecoder().decode(NewsItem.self, from: data)

    #expect(decoded.id == original.id)
    #expect(decoded.headline == original.headline)
    #expect(decoded.summary == original.summary)
    #expect(decoded.source == original.source)
    #expect(decoded.articleURL == original.articleURL)
    #expect(decoded.category == original.category)
    #expect(decoded.coordinate == original.coordinate)
    #expect(decoded.publishedAt == original.publishedAt)
    #expect(decoded.imageURL == original.imageURL)
    #expect(decoded.analysis == original.analysis)
  }

  // MARK: - GeoCoordinate Codable Validation

  @Test("GeoCoordinate decodes valid JSON correctly")
  func geoCoordinateDecodeValid() throws {
    let json = #"{"latitude": 41.0082, "longitude": 28.9784}"#
    let data = json.data(using: .utf8)!
    let coord = try JSONDecoder().decode(GeoCoordinate.self, from: data)
    #expect(coord.latitude == 41.0082)
    #expect(coord.longitude == 28.9784)
  }

  @Test("GeoCoordinate rejects invalid latitude during decoding")
  func geoCoordinateDecodeInvalidLatitude() {
    let json = #"{"latitude": 999.0, "longitude": 28.0}"#
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(GeoCoordinate.self, from: data)
    }
  }

  @Test("GeoCoordinate rejects invalid longitude during decoding")
  func geoCoordinateDecodeInvalidLongitude() {
    let json = #"{"latitude": 41.0, "longitude": -200.0}"#
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(GeoCoordinate.self, from: data)
    }
  }

  @Test("GeoCoordinate Codable round-trip preserves values")
  func geoCoordinateCodableRoundTrip() throws {
    let original = GeoCoordinate(latitude: -33.8688, longitude: 151.2093)!
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(GeoCoordinate.self, from: data)
    #expect(decoded == original)
  }

  // MARK: - NerveError LocalizedError

  @Test("NerveError errorDescription contains message for all cases")
  func nerveErrorDescriptions() {
    let cases: [(NerveError, String)] = [
      (.network(message: "timeout"), "Network error: timeout"),
      (.storage(message: "full"), "Storage error: full"),
      (.ai(message: "model fail"), "AI analysis error: model fail"),
      (.location(message: "denied"), "Location error: denied"),
      (.dependency(message: "missing"), "Dependency error: missing"),
      (.unknown(message: "oops"), "Unexpected error: oops"),
    ]

    for (error, expectedDescription) in cases {
      #expect(error.errorDescription == expectedDescription)
    }
  }

  @Test("NerveError with context still equals error without context")
  func nerveErrorEquatableIgnoresContext() {
    let withContext = NerveError.network(
      message: "timeout",
      context: ErrorContext(underlyingError: URLError(.timedOut))
    )
    let withoutContext = NerveError.network(message: "timeout")
    #expect(withContext == withoutContext)
  }
}
