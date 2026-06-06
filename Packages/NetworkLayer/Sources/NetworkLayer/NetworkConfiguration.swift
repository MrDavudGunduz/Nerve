//
//  NetworkConfiguration.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Core
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

  /// SHA-256 hashes of pinned server certificate public keys.
  ///
  /// When non-empty, the ``CertificatePinningDelegate`` is attached to
  /// sessions created by ``makeURLSession()``, enforcing that the server's
  /// leaf certificate matches one of these hashes.
  ///
  /// Include at least **two** hashes (primary + backup CA) to avoid
  /// bricking the app during certificate rotation.
  ///
  /// Empty by default — no pinning is enforced until hashes are configured.
  public let pinnedCertificateHashes: Set<String>

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
    imageCacheSizeMB: Int = 100,
    pinnedCertificateHashes: Set<String> = []
  ) {
    self.baseURL = baseURL
    self.timeoutInterval = timeoutInterval
    self.maxRetryAttempts = maxRetryAttempts
    self.retryBaseDelay = retryBaseDelay
    self.apiKey = apiKey
    self.additionalHeaders = additionalHeaders
    self.maxConcurrentImageDownloads = maxConcurrentImageDownloads
    self.imageCacheSizeMB = imageCacheSizeMB
    self.pinnedCertificateHashes = pinnedCertificateHashes
  }

  // MARK: - Validated URL Constants

  /// Pre-validated base URLs for each environment.
  ///
  /// Using `static let` avoids force-unwrap (`!`) at each call site.
  /// These URLs are structurally guaranteed to be valid — the `assertionFailure`
  /// is a development-time safety net that never triggers in production.
  private static let productionBaseURL: URL = {
    guard let url = URL(string: "https://api.nerve.app/v1") else {
      assertionFailure("Invalid production base URL — this is a build configuration error.")
      // swiftlint:disable:next force_unwrapping
      return URL(string: "https://api.nerve.app/v1")!
    }
    return url
  }()

  private static let stagingBaseURL: URL = {
    guard let url = URL(string: "https://staging-api.nerve.app/v1") else {
      assertionFailure("Invalid staging base URL — this is a build configuration error.")
      // swiftlint:disable:next force_unwrapping
      return URL(string: "https://staging-api.nerve.app/v1")!
    }
    return url
  }()

  private static let developmentBaseURL: URL = {
    guard let url = URL(string: "http://localhost:8080/v1") else {
      assertionFailure("Invalid development base URL — this is a build configuration error.")
      // swiftlint:disable:next force_unwrapping
      return URL(string: "http://localhost:8080/v1")!
    }
    return url
  }()

  /// Production configuration targeting the live API.
  ///
  /// Includes placeholder certificate hashes — replace with actual SPKI
  /// SHA-256 hashes before App Store submission.
  public static let production = NetworkConfiguration(
    baseURL: productionBaseURL,
    timeoutInterval: 30,
    maxRetryAttempts: 3,
    retryBaseDelay: 1.0,
    pinnedCertificateHashes: [
      // TODO: Replace with actual SPKI SHA-256 hashes before production release.
      // Generate with:
      //   openssl s_client -connect api.nerve.app:443 | openssl x509 -pubkey -noout | \
      //   openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | base64
      // "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",  // Primary
      // "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=",  // Backup CA
    ]
  )

  /// Staging configuration for QA/testing environments.
  public static let staging = NetworkConfiguration(
    baseURL: stagingBaseURL,
    timeoutInterval: 15,
    maxRetryAttempts: 2,
    retryBaseDelay: 0.5
  )

  /// Development configuration for local testing.
  ///
  /// Points to localhost with aggressive timeouts, no retries,
  /// and no certificate pinning.
  public static let development = NetworkConfiguration(
    baseURL: developmentBaseURL,
    timeoutInterval: 10,
    maxRetryAttempts: 1,
    retryBaseDelay: 0.1
  )

  /// Creates a configured `URLSession` with the appropriate timeout,
  /// caching policy, and certificate pinning delegate.
  ///
  /// A dedicated session per service avoids cross-contamination of
  /// cookies, caches, and authentication state.
  ///
  /// When ``pinnedCertificateHashes`` is non-empty and
  /// ``FeatureFlags/certificatePinningEnabled`` is `true`, a
  /// ``CertificatePinningDelegate`` is attached to enforce SPKI pinning.
  public func makeURLSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeoutInterval
    config.timeoutIntervalForResource = timeoutInterval * 2
    config.waitsForConnectivity = true
    config.httpAdditionalHeaders = buildHeaders()

    // Attach certificate pinning delegate when hashes are configured.
    if !pinnedCertificateHashes.isEmpty {
      let pinningDelegate = CertificatePinningDelegate(
        pinnedHashes: pinnedCertificateHashes
      )
      return URLSession(
        configuration: config,
        delegate: pinningDelegate,
        delegateQueue: nil
      )
    }

    return URLSession(configuration: config)
  }

  // MARK: - Private

  /// Builds the full HTTP header dictionary including API key and custom headers.
  ///
  /// API key resolution order:
  /// 1. Explicit `apiKey` property (constructor-injected).
  /// 2. Keychain-stored key via ``KeychainStore``.
  ///
  /// This layered approach allows tests and previews to inject keys directly
  /// while production builds resolve from the Keychain.
  private func buildHeaders() -> [String: String] {
    var headers: [String: String] = [
      "Accept": "application/json",
      "Content-Type": "application/json",
      "User-Agent": Self.userAgent,
    ]

    // Resolve API key: explicit property takes precedence over Keychain.
    let resolvedKey = apiKey ?? KeychainStore.load(for: .apiKey)
    if let resolvedKey {
      headers["Authorization"] = "Bearer \(resolvedKey)"
    }

    // Custom headers override defaults.
    for (key, value) in additionalHeaders {
      headers[key] = value
    }

    return headers
  }

  /// Dynamically built User-Agent string reflecting the actual app version and platform.
  ///
  /// Format: `Nerve/<version> (<platform>; <os> <osVersion>)`
  /// Example: `Nerve/1.2.0 (Apple; iOS 17.5)`
  private static let userAgent: String = {
    let bundle = Bundle.main
    let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    #if os(iOS)
      let platform = "iOS"
    #elseif os(macOS)
      let platform = "macOS"
    #elseif os(visionOS)
      let platform = "visionOS"
    #else
      let platform = "Apple"
    #endif

    let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    return "Nerve/\(appVersion).\(buildNumber) (Apple; \(platform) \(osVersion))"
  }()
}
