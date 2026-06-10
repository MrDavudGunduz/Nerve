//
//  RetryAfterParsingTests.swift
//  NetworkLayerTests
//
//  Created by Davud Gunduz on 10.06.2026.
//

import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - Retry-After Parsing Tests

/// Tests verifying the `Retry-After` response header parsing logic in
/// ``URLSessionNewsService``.
///
/// Covers both RFC 9110 §10.2.3 formats:
/// - **Delta-seconds:** e.g. `"120"` → 120.0 seconds.
/// - **HTTP-date:** e.g. `"Sun, 10 Jun 2026 18:00:00 GMT"` → future delta.
///
/// Also verifies edge cases: missing header, empty value, negative values,
/// invalid formats, and zero values.
@Suite("Retry-After Header Parsing Tests")
struct RetryAfterParsingTests {

  // MARK: - Helper

  /// Creates an `HTTPURLResponse` with the given `Retry-After` header value.
  ///
  /// - Parameter retryAfterValue: The value for the `Retry-After` header.
  ///   Pass `nil` to omit the header entirely.
  /// - Returns: A configured `HTTPURLResponse` with status 429.
  private func makeResponse(retryAfterValue: String?) -> HTTPURLResponse {
    var headers: [String: String] = ["Content-Type": "application/json"]
    if let retryAfterValue {
      headers["Retry-After"] = retryAfterValue
    }

    return HTTPURLResponse(
      url: URL(string: "https://api.nerve.app/v1/news")!,
      statusCode: 429,
      httpVersion: "HTTP/1.1",
      headerFields: headers
    )!
  }

  // MARK: - Delta-Seconds Format

  @Test("Parses integer delta-seconds correctly")
  func deltaSecondsInteger() {
    let response = makeResponse(retryAfterValue: "120")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == 120.0)
  }

  @Test("Parses small delta-seconds correctly")
  func deltaSecondsSmall() {
    let response = makeResponse(retryAfterValue: "1")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == 1.0)
  }

  @Test("Parses large delta-seconds correctly")
  func deltaSecondsLarge() {
    let response = makeResponse(retryAfterValue: "3600")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == 3600.0)
  }

  @Test("Parses fractional delta-seconds correctly")
  func deltaSecondsFractional() {
    let response = makeResponse(retryAfterValue: "0.5")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == 0.5)
  }

  // MARK: - Edge Cases

  @Test("Returns nil for missing Retry-After header")
  func missingHeader() {
    let response = makeResponse(retryAfterValue: nil)
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil)
  }

  @Test("Returns nil for empty Retry-After value")
  func emptyValue() {
    let response = makeResponse(retryAfterValue: "")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil)
  }

  @Test("Returns nil for zero delta-seconds")
  func zeroDeltaSeconds() {
    let response = makeResponse(retryAfterValue: "0")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil, "Zero delay should return nil — no meaningful wait")
  }

  @Test("Returns nil for negative delta-seconds")
  func negativeDeltaSeconds() {
    let response = makeResponse(retryAfterValue: "-10")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil, "Negative delay should return nil")
  }

  @Test("Returns nil for non-numeric, non-date value")
  func invalidFormat() {
    let response = makeResponse(retryAfterValue: "not-a-number")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil)
  }

  @Test("Returns nil for whitespace-only value")
  func whitespaceOnly() {
    let response = makeResponse(retryAfterValue: "   ")
    let result = URLSessionNewsService.parseRetryAfter(from: response)
    #expect(result == nil)
  }

  // MARK: - HTTP-Date Format

  @Test("Parses future HTTP-date correctly")
  func futureHTTPDate() {
    // Create a date 60 seconds in the future.
    let futureDate = Date(timeIntervalSinceNow: 60)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    let dateString = formatter.string(from: futureDate)

    let response = makeResponse(retryAfterValue: dateString)
    let result = URLSessionNewsService.parseRetryAfter(from: response)

    // The parsed delay should be approximately 60 seconds (±2 for execution time).
    #expect(result != nil)
    if let result {
      #expect(result > 55.0 && result < 65.0, "Expected ~60s, got \(result)s")
    }
  }

  @Test("Returns nil for past HTTP-date")
  func pastHTTPDate() {
    // Create a date 60 seconds in the past.
    let pastDate = Date(timeIntervalSinceNow: -60)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    let dateString = formatter.string(from: pastDate)

    let response = makeResponse(retryAfterValue: dateString)
    let result = URLSessionNewsService.parseRetryAfter(from: response)

    #expect(result == nil, "Past dates should return nil")
  }

  // MARK: - Integration with NerveError

  @Test("NerveError.network carries parsed retryAfter value")
  func nerveErrorCarriesRetryAfter() {
    let error = NerveError.network(
      message: "Rate limited (HTTP 429). Retrying after backoff.",
      reason: .rateLimited,
      retryAfter: 45.0
    )

    if case .network(_, let reason, let retryAfter, _) = error {
      #expect(reason == .rateLimited)
      #expect(retryAfter == 45.0)
    } else {
      Issue.record("Expected .network case with retryAfter")
    }
  }

  @Test("NerveError.network without retryAfter defaults to nil")
  func nerveErrorDefaultRetryAfter() {
    let error = NerveError.network(
      message: "Rate limited.",
      reason: .rateLimited
    )

    if case .network(_, _, let retryAfter, _) = error {
      #expect(retryAfter == nil)
    } else {
      Issue.record("Expected .network case")
    }
  }
}
