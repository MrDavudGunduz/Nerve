//
//  NetworkConfigurationTests.swift
//  NetworkLayerTests
//
//  Created by Davud Gunduz on 19.05.2026.
//

import Core
import Foundation
import Testing

@testable import NetworkLayer

// MARK: - NetworkConfiguration Header Tests

/// Tests verifying ``NetworkConfiguration``'s HTTP header construction,
/// URLSession factory, and User-Agent generation.
@Suite("NetworkConfiguration Header & Factory Tests")
struct NetworkConfigurationHeaderTests {

  @Test("Production session includes JSON headers")
  func productionSessionHeaders() {
    let config = NetworkConfiguration.production
    let session = config.makeURLSession()

    let headers = session.configuration.httpAdditionalHeaders as? [String: String]
    #expect(headers?["Accept"] == "application/json")
    #expect(headers?["Content-Type"] == "application/json")
  }

  @Test("API key is included in Authorization header when provided")
  func apiKeyHeader() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://test.api.com/v1")!,
      apiKey: "test-api-key-12345"
    )
    let session = config.makeURLSession()

    let headers = session.configuration.httpAdditionalHeaders as? [String: String]
    #expect(headers?["Authorization"] == "Bearer test-api-key-12345")
  }

  @Test("No Authorization header when API key is nil")
  func noApiKeyHeader() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://test.api.com/v1")!,
      apiKey: nil
    )
    let session = config.makeURLSession()

    let headers = session.configuration.httpAdditionalHeaders as? [String: String]
    #expect(headers?["Authorization"] == nil)
  }

  @Test("Custom headers override defaults")
  func customHeadersOverride() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://test.api.com/v1")!,
      additionalHeaders: [
        "Accept": "text/plain",  // Override default.
        "X-Custom-Header": "custom-value",
      ]
    )
    let session = config.makeURLSession()

    let headers = session.configuration.httpAdditionalHeaders as? [String: String]
    #expect(headers?["Accept"] == "text/plain")
    #expect(headers?["X-Custom-Header"] == "custom-value")
    // Content-Type should still be set.
    #expect(headers?["Content-Type"] == "application/json")
  }

  @Test("User-Agent header contains Nerve prefix")
  func userAgentFormat() {
    let config = NetworkConfiguration.production
    let session = config.makeURLSession()

    let headers = session.configuration.httpAdditionalHeaders as? [String: String]
    let userAgent = headers?["User-Agent"] ?? ""
    #expect(userAgent.hasPrefix("Nerve/"))
    #expect(userAgent.contains("Apple;"))
  }

  @Test("Resource timeout is 2x request timeout")
  func resourceTimeout() {
    let config = NetworkConfiguration(
      baseURL: URL(string: "https://test.api.com/v1")!,
      timeoutInterval: 20
    )
    let session = config.makeURLSession()

    #expect(session.configuration.timeoutIntervalForRequest == 20)
    #expect(session.configuration.timeoutIntervalForResource == 40)
  }

  @Test("waitsForConnectivity is enabled")
  func waitsForConnectivity() {
    let config = NetworkConfiguration.production
    let session = config.makeURLSession()

    #expect(session.configuration.waitsForConnectivity)
  }
}

// MARK: - NetworkConfiguration Sendable Tests

@Suite("NetworkConfiguration Sendable Tests")
struct NetworkConfigurationSendableTests {

  @Test("NetworkConfiguration is Sendable — can be captured in Task")
  func sendable() async {
    let config = NetworkConfiguration.production

    let result = await Task {
      config.baseURL.absoluteString
    }.value

    #expect(result == "https://api.nerve.app/v1")
  }

  @Test("All preset configurations have valid base URLs")
  func presetBaseURLs() {
    let presets: [NetworkConfiguration] = [
      .production, .staging, .development,
    ]

    for preset in presets {
      #expect(preset.baseURL.scheme != nil)
      #expect(preset.baseURL.host != nil)
      #expect(preset.baseURL.pathComponents.contains("v1"))
    }
  }
}
