//
//  NetworkConfiguration.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Foundation

// MARK: - NetworkConfiguration

/// Centralized configuration for the network layer.
///
/// Defines base URLs, timeouts, retry policies, and HTTP headers
/// used across all `URLSession`-based services in `NetworkLayer`.
///
/// ## Environment Switching
///
/// ```swift
/// #if DEBUG
///   let config = NetworkConfiguration.staging
/// #else
///   let config = NetworkConfiguration.production
/// #endif
/// ```
///
/// ## Custom Configuration
///
/// ```swift
/// let config = NetworkConfiguration(
///   baseURL: URL(string: "https://api.custom.com/v1")!,
///   timeoutInterval: 15,
///   maxRetryAttempts: 2
/// )
/// ```
public struct NetworkConfiguration: Sendable {

  // MARK: - Properties

  /// The base URL for the news REST API.
  public let baseURL: URL

  /// The timeout interval for individual requests, in seconds.
  public let timeoutInterval: TimeInterval

  /// Maximum retry attempts for transient failures.
  public let maxRetryAttempts: Int

  /// Base delay (in seconds) before the first retry.
  public let retryBaseDelay: TimeInterval

  /// Optional API key for authentication headers.
  public let apiKey: String?

  /// Additional HTTP headers applied to every request.
  public let additionalHeaders: [String: String]

  /// Maximum number of concurrent image download tasks.
  public let maxConcurrentImageDownloads: Int

  /// In-memory image cache size limit in megabytes.
  public let imageCacheSizeMB: Int

  // MARK: - Init

  /// Creates a network configuration with the specified parameters.
  ///
  /// - Parameters:
  ///   - baseURL: The API base URL.
  ///   - timeoutInterval: Request timeout in seconds (default: 30).
  ///   - maxRetryAttempts: Max retry count for transient errors (default: 3).
  ///   - retryBaseDelay: Base delay before first retry (default: 1.0s).
  ///   - apiKey: Optional API key (default: nil).
  ///   - additionalHeaders: Extra HTTP headers (default: empty).
  ///   - maxConcurrentImageDownloads: Concurrent image download limit (default: 4).
  ///   - imageCacheSizeMB: Image cache size in MB (default: 100).
  public init(
    baseURL: URL,
    timeoutInterval: TimeInterval = 30,
    maxRetryAttempts: Int = 3,
    retryBaseDelay: TimeInterval = 1.0,
    apiKey: String? = nil,
    additionalHeaders: [String: String] = [:],
    maxConcurrentImageDownloads: Int = 4,
    imageCacheSizeMB: Int = 100
  ) {
    self.baseURL = baseURL
    self.timeoutInterval = timeoutInterval
    self.maxRetryAttempts = maxRetryAttempts
    self.retryBaseDelay = retryBaseDelay
    self.apiKey = apiKey
    self.additionalHeaders = additionalHeaders
    self.maxConcurrentImageDownloads = maxConcurrentImageDownloads
    self.imageCacheSizeMB = imageCacheSizeMB
  }

  // MARK: - Presets

  /// Production configuration targeting the live API.
  public static let production = NetworkConfiguration(
    baseURL: URL(string: "https://api.nerve.app/v1")!,
    timeoutInterval: 30,
    maxRetryAttempts: 3,
    retryBaseDelay: 1.0
  )

  /// Staging configuration for QA/testing environments.
  public static let staging = NetworkConfiguration(
    baseURL: URL(string: "https://staging-api.nerve.app/v1")!,
    timeoutInterval: 15,
    maxRetryAttempts: 2,
    retryBaseDelay: 0.5
  )

  /// Development configuration for local testing.
  ///
  /// Points to localhost with aggressive timeouts and no retries.
  public static let development = NetworkConfiguration(
    baseURL: URL(string: "http://localhost:8080/v1")!,
    timeoutInterval: 10,
    maxRetryAttempts: 1,
    retryBaseDelay: 0.1
  )

  // MARK: - URLSession Factory

  /// Creates a configured `URLSession` with the appropriate timeout
  /// and caching policy.
  ///
  /// A dedicated session per service avoids cross-contamination of
  /// cookies, caches, and authentication state.
  public func makeURLSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeoutInterval
    config.timeoutIntervalForResource = timeoutInterval * 2
    config.waitsForConnectivity = true
    config.httpAdditionalHeaders = buildHeaders()
    return URLSession(configuration: config)
  }

  // MARK: - Private

  /// Builds the full HTTP header dictionary including API key and custom headers.
  private func buildHeaders() -> [String: String] {
    var headers: [String: String] = [
      "Accept": "application/json",
      "Content-Type": "application/json",
      "User-Agent": "Nerve/1.0 (Apple; iOS)",
    ]

    if let apiKey {
      headers["Authorization"] = "Bearer \(apiKey)"
    }

    // Custom headers override defaults.
    for (key, value) in additionalHeaders {
      headers[key] = value
    }

    return headers
  }
}
