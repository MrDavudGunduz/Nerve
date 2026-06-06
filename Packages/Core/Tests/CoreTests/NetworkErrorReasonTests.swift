//
//  NetworkErrorReasonTests.swift
//  CoreTests
//
//  Created by Davud Gunduz on 14.05.2026.
//

import Core
import Foundation
import Testing

/// Tests for the structured ``NetworkErrorReason`` enum and its integration
/// with ``NerveError``.
@Suite("NetworkErrorReason Tests")
struct NetworkErrorReasonTests {

  // MARK: - Retryable Classification

  @Test("Retryable reasons return true for isRetryable")
  func retryableReasons() {
    let retryable: [NetworkErrorReason] = [
      .rateLimited, .serverError, .timeout, .connectionLost,
    ]
    for reason in retryable {
      #expect(reason.isRetryable, "\(reason.rawValue) should be retryable")
    }
  }

  @Test("Non-retryable reasons return false for isRetryable")
  func nonRetryableReasons() {
    let nonRetryable: [NetworkErrorReason] = [
      .noConnection, .unauthorized, .notFound, .other,
    ]
    for reason in nonRetryable {
      #expect(!reason.isRetryable, "\(reason.rawValue) should NOT be retryable")
    }
  }

  // MARK: - NerveError Integration

  @Test("NerveError.network includes reason in debugDescription")
  func networkErrorDebugDescription() {
    let error = NerveError.network(
      message: "HTTP 429", reason: .rateLimited
    )
    let desc = error.debugDescription
    #expect(desc.contains("rateLimited"), "Debug description should include reason")
    #expect(desc.contains("HTTP 429"), "Debug description should include message")
  }

  @Test("NerveError.network without explicit reason defaults to .other")
  func networkErrorDefaultsToOtherReason() {
    let error = NerveError.network(message: "Unknown failure")
    let desc = error.debugDescription
    // reason is now non-optional — default is .other, always included in debugDescription.
    #expect(desc.contains("reason: other"), "Default reason .other should appear in debugDescription")
  }

  @Test("NerveError.network Equatable considers reason")
  func networkErrorEquatable() {
    let error1 = NerveError.network(message: "fail", reason: .timeout)
    let error2 = NerveError.network(message: "fail", reason: .timeout)
    let error3 = NerveError.network(message: "fail", reason: .rateLimited)
    let error4 = NerveError.network(message: "fail")  // defaults to .other
    let error5 = NerveError.network(message: "fail", reason: .other)

    #expect(error1 == error2, "Same message + reason should be equal")
    #expect(error1 != error3, "Different reasons should not be equal")
    #expect(error1 != error4, ".timeout vs default .other should not be equal")
    #expect(error4 == error5, "Default .other should equal explicit .other")
  }

  @Test("NetworkErrorReason is Codable round-trip safe")
  func codableRoundTrip() throws {
    for reason in [
      NetworkErrorReason.rateLimited, .serverError, .timeout,
      .noConnection, .connectionLost, .unauthorized, .notFound, .other,
    ] {
      let data = try JSONEncoder().encode(reason)
      let decoded = try JSONDecoder().decode(NetworkErrorReason.self, from: data)
      #expect(decoded == reason, "\(reason.rawValue) should survive Codable round-trip")
    }
  }
}
