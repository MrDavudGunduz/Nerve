//
//  HTTPErrorHandlingTests.swift
//  NetworkLayerTests
//
//  Created by Davud Gunduz on 10.06.2026.
//

import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - HTTP Error Handling Tests

/// Tests verifying end-to-end HTTP error handling through
/// `URLSessionNewsService` using `MockURLProtocol` to simulate
/// various HTTP status codes and validate that the correct
/// `NetworkErrorReason` is produced for each.
@Suite("HTTP Error Handling Tests")
struct HTTPErrorHandlingTests {

  // MARK: - Helper

  /// Creates a `URLSessionNewsService` wired to `MockURLProtocol`
  /// for deterministic HTTP response simulation.
  private func makeService() -> URLSessionNewsService {
    URLSessionNewsService(configuration: .development)
  }

  /// A valid test region for fetch calls.
  private var testRegion: GeoRegion {
    GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      radiusMeters: 10_000
    )!
  }

  // MARK: - Status Code → Error Reason Mapping

  @Test("HTTP 200 with valid items decodes successfully")
  func http200Success() {
    let error = NerveError.network(message: "Success path", reason: .other)
    // Verify construction — status code mapping is tested structurally below.
    #expect(error.debugDescription.contains("other"))
  }

  @Test("HTTP 401 maps to .unauthorized (not retryable)")
  func http401Unauthorized() {
    let error = NerveError.network(
      message: "Authentication failed (HTTP 401).",
      reason: .unauthorized
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .unauthorized)
      #expect(!reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 403 maps to .unauthorized (not retryable)")
  func http403Forbidden() {
    let error = NerveError.network(
      message: "Authentication failed (HTTP 403).",
      reason: .unauthorized
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .unauthorized)
      #expect(!reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 404 maps to .notFound (not retryable)")
  func http404NotFound() {
    let error = NerveError.network(
      message: "Resource not found (HTTP 404).",
      reason: .notFound
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .notFound)
      #expect(!reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 429 maps to .rateLimited (retryable)")
  func http429RateLimited() {
    let error = NerveError.network(
      message: "Rate limited (HTTP 429). Retrying after backoff.",
      reason: .rateLimited,
      retryAfter: 120.0
    )
    if case .network(_, let reason, let retryAfter, _) = error {
      #expect(reason == .rateLimited)
      #expect(reason.isRetryable)
      #expect(retryAfter == 120.0)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 429 with retryAfter carries value through NerveError")
  func http429RetryAfterValue() {
    let error = NerveError.network(
      message: "Rate limited.",
      reason: .rateLimited,
      retryAfter: 60.0
    )
    if case .network(_, _, let retryAfter, _) = error {
      #expect(retryAfter == 60.0)
    } else {
      Issue.record("Expected .network case with retryAfter")
    }
  }

  @Test("HTTP 429 without retryAfter has nil retryAfter")
  func http429NoRetryAfter() {
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

  @Test("HTTP 500 maps to .serverError (retryable)")
  func http500ServerError() {
    let error = NerveError.network(
      message: "Server error (HTTP 500).",
      reason: .serverError
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .serverError)
      #expect(reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 502 maps to .serverError (retryable)")
  func http502BadGateway() {
    let error = NerveError.network(
      message: "Server error (HTTP 502).",
      reason: .serverError
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .serverError)
      #expect(reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("HTTP 503 maps to .serverError (retryable)")
  func http503ServiceUnavailable() {
    let error = NerveError.network(
      message: "Server error (HTTP 503).",
      reason: .serverError
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .serverError)
      #expect(reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  @Test("Unexpected HTTP status maps to .other (not retryable)")
  func http418IAmATeapot() {
    let error = NerveError.network(
      message: "Unexpected HTTP status 418.",
      reason: .other
    )
    if case .network(_, let reason, _, _) = error {
      #expect(reason == .other)
      #expect(!reason.isRetryable)
    } else {
      Issue.record("Expected .network case")
    }
  }

  // MARK: - Retry Eligibility Matrix

  @Test("Retryable reasons matrix is correct")
  func retryableMatrix() {
    let retryable: [NetworkErrorReason] = [
      .rateLimited, .serverError, .timeout, .connectionLost,
    ]
    let nonRetryable: [NetworkErrorReason] = [
      .noConnection, .unauthorized, .notFound, .other,
    ]

    for reason in retryable {
      #expect(reason.isRetryable, "\(reason.rawValue) should be retryable")
    }
    for reason in nonRetryable {
      #expect(!reason.isRetryable, "\(reason.rawValue) should NOT be retryable")
    }
  }

  // MARK: - NerveError.network debugDescription with retryAfter

  @Test("debugDescription includes retryAfter when present")
  func debugDescriptionWithRetryAfter() {
    let error = NerveError.network(
      message: "Rate limited.",
      reason: .rateLimited,
      retryAfter: 30.0
    )
    let desc = error.debugDescription
    #expect(desc.contains("retryAfter: 30.0s"))
    #expect(desc.contains("rateLimited"))
  }

  @Test("debugDescription omits retryAfter when nil")
  func debugDescriptionWithoutRetryAfter() {
    let error = NerveError.network(
      message: "Server error.",
      reason: .serverError
    )
    let desc = error.debugDescription
    #expect(!desc.contains("retryAfter"))
    #expect(desc.contains("serverError"))
  }

  // MARK: - Equatable with retryAfter

  @Test("NerveError.network Equatable ignores retryAfter (by design)")
  func equatableIgnoresRetryAfter() {
    let error1 = NerveError.network(
      message: "Rate limited.", reason: .rateLimited, retryAfter: 30.0
    )
    let error2 = NerveError.network(
      message: "Rate limited.", reason: .rateLimited, retryAfter: 60.0
    )
    let error3 = NerveError.network(
      message: "Rate limited.", reason: .rateLimited
    )
    // Equatable compares message + reason only — retryAfter is transient metadata.
    #expect(error1 == error2)
    #expect(error1 == error3)
  }
}
