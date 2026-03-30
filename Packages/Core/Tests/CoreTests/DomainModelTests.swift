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
}
