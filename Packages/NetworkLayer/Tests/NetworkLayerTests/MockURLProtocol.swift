//
//  MockURLProtocol.swift
//  NetworkLayerTests
//
//  Created by Davud Gunduz on 19.05.2026.
//

import Foundation

// MARK: - MockURLProtocol

/// A `URLProtocol` subclass that intercepts all requests for deterministic
/// testing of `URLSession`-based services.
///
/// ## Usage
///
/// ```swift
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
///
/// MockURLProtocol.stubResponseData = validJSON
/// MockURLProtocol.stubStatusCode = 200
/// ```
///
/// ## Thread Safety
///
/// Properties are set before each test and read during synchronous
/// `URLProtocol` callbacks — no concurrent mutation expected.
/// All stubs are reset in `tearDown` via ``reset()``.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

  // MARK: - Stubs

  /// The data to return in the response body.
  nonisolated(unsafe) static var stubResponseData: Data?

  /// The HTTP status code to return (default: 200).
  nonisolated(unsafe) static var stubStatusCode: Int = 200

  /// An error to throw instead of returning a response.
  nonisolated(unsafe) static var stubError: Error?

  /// Response headers to include (default: JSON content type).
  nonisolated(unsafe) static var stubHeaders: [String: String] = [
    "Content-Type": "application/json",
  ]

  /// Captured request for assertion in tests.
  nonisolated(unsafe) static var lastRequest: URLRequest?

  // MARK: - Reset

  /// Resets all stubs to defaults. Call in test teardown.
  static func reset() {
    stubResponseData = nil
    stubStatusCode = 200
    stubError = nil
    stubHeaders = ["Content-Type": "application/json"]
    lastRequest = nil
  }

  // MARK: - URLProtocol Overrides

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    Self.lastRequest = request

    if let error = Self.stubError {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: Self.stubStatusCode,
      httpVersion: "HTTP/1.1",
      headerFields: Self.stubHeaders
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

    if let data = Self.stubResponseData {
      client?.urlProtocol(self, didLoad: data)
    }

    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
