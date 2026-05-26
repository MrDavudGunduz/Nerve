//
//  URLSessionNewsService.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Core
import Foundation
import OSLog

// MARK: - URLSessionNewsService

/// Production implementation of ``NewsServiceProtocol`` using `URLSession`.
///
/// Fetches geographically-tagged news data from the Nerve REST API.
/// All requests include automatic retry with exponential backoff via
/// ``RetryPolicy`` for transient failures (timeouts, 5xx errors).
///
/// ## Architecture
///
/// - Uses a dedicated `URLSession` configured by ``NetworkConfiguration``.
/// - Decodes JSON responses into domain ``NewsItem`` instances via an
///   intermediate ``NewsItemDTO`` (Data Transfer Object).
/// - HTTP error classification determines retry eligibility.
///
/// ## URLSession Lifecycle
///
/// Each `URLSessionNewsService` instance creates its own `URLSession` via
/// ``NetworkConfiguration/makeURLSession()``. This is **intentional** —
/// per-instance sessions prevent cross-contamination of cookies, caches,
/// and authentication state between different configuration environments
/// (production vs. staging vs. development). Since the service is registered
/// as a singleton in ``AppBootstrapper``, only one session exists at runtime.
///
/// ## Thread Safety
///
/// `URLSessionNewsService` is a value type (`struct`) conforming to
/// `Sendable`. It captures only `Sendable` dependencies (`URLSession`,
/// `JSONDecoder`, configuration values).
///
/// ## Usage
///
/// ```swift
/// let service = URLSessionNewsService(
///   configuration: .production
/// )
/// let items = try await service.fetchNews(for: visibleRegion)
/// ```
public struct URLSessionNewsService: NewsServiceProtocol {

  // MARK: - Dependencies

  private let session: URLSession
  private let configuration: NetworkConfiguration
  private let decoder: JSONDecoder

  private static let logger = Logger(
    subsystem: LogSubsystem.networkLayer,
    category: "URLSessionNewsService"
  )

  // MARK: - Init

  /// Creates a news service backed by `URLSession`.
  ///
  /// - Parameter configuration: The network configuration to use.
  ///   Defaults to ``NetworkConfiguration/production``.
  public init(configuration: NetworkConfiguration = .production) {
    self.configuration = configuration
    self.session = configuration.makeURLSession()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder = decoder
  }

  // MARK: - NewsServiceProtocol

  /// Fetches news items within the given geographic region.
  ///
  /// Constructs a bounding-box query from the region's center and radius,
  /// then issues a GET request to `/news` with spatial parameters.
  ///
  /// Retries automatically on transient failures (timeouts, server errors).
  ///
  /// - Parameter region: The area to scope the query to.
  /// - Returns: An array of ``NewsItem`` instances (may be empty).
  /// - Throws: ``NerveError/network(message:context:)`` on unrecoverable failure.
  public func fetchNews(for region: GeoRegion) async throws -> [NewsItem] {
    let url = try buildFetchURL(for: region)

    Self.logger.info(
      "Fetching news for region center=(\(region.center.latitude), \(region.center.longitude)), radius=\(region.radiusMeters)m"
    )

    do {
      let data = try await RetryPolicy.execute(
        maxAttempts: configuration.maxRetryAttempts,
        baseDelay: configuration.retryBaseDelay,
        shouldRetry: { Self.isRetryableError($0) }
      ) {
        let (data, response) = try await session.data(from: url)
        try Self.validateHTTPResponse(response, data: data)
        return data
      }

      let envelope = try decoder.decode(NewsResponseEnvelope.self, from: data)
      Self.logger.info("Decoded \(envelope.items.count) news items from API.")
      return envelope.items.map { $0.toDomainModel() }

    } catch let nerveError as NerveError {
      throw nerveError
    } catch {
      throw NerveError.network(
        message: "fetchNews failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  /// Fetches the full details of a single news item.
  ///
  /// The `id` is percent-encoded before path construction to prevent
  /// malformed URLs when the upstream API returns IDs containing
  /// reserved characters (`/`, `%`, `?`, `#`, etc.).
  ///
  /// - Parameter id: The unique identifier of the news item.
  /// - Returns: The matching ``NewsItem``.
  /// - Throws: ``NerveError/network(message:context:)`` on failure.
  public func fetchNewsDetail(id: String) async throws -> NewsItem {
    let sanitizedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    let url = configuration.baseURL.appendingPathComponent("news/\(sanitizedID)")

    do {
      let data = try await RetryPolicy.execute(
        maxAttempts: configuration.maxRetryAttempts,
        baseDelay: configuration.retryBaseDelay,
        shouldRetry: { Self.isRetryableError($0) }
      ) {
        let (data, response) = try await session.data(from: url)
        try Self.validateHTTPResponse(response, data: data)
        return data
      }

      let dto = try decoder.decode(NewsItemDTO.self, from: data)
      return dto.toDomainModel()

    } catch let nerveError as NerveError {
      throw nerveError
    } catch {
      throw NerveError.network(
        message: "fetchNewsDetail(id: '\(id)') failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  // MARK: - URL Construction

  /// Builds the fetch URL with bounding-box query parameters.
  ///
  /// - Parameter region: The geographic region to construct the query for.
  /// - Returns: A fully-formed URL with bounding-box query parameters.
  /// - Throws: ``NerveError/network(message:)`` if the base URL cannot be
  ///   decomposed into `URLComponents` or the final URL is invalid.
  private func buildFetchURL(for region: GeoRegion) throws -> URL {
    // Approximate bounding box: 1° latitude ≈ 111 km.
    let latDelta = region.radiusMeters / 111_000
    // Guard against cos(90°) = 0 at polar latitudes, which would produce
    // lonDelta = Infinity. The floor of 0.01 caps the maximum bounding box
    // to ±(radius / 1_110) degrees — still a valid approximation.
    let cosLat = max(cos(region.center.latitude * .pi / 180), 0.01)
    let lonDelta = region.radiusMeters / (111_000 * cosLat)

    guard var components = URLComponents(
      url: configuration.baseURL.appendingPathComponent("news"),
      resolvingAgainstBaseURL: false
    ) else {
      throw NerveError.network(
        message: "Failed to construct URLComponents from base URL: \(configuration.baseURL)",
        reason: .other
      )
    }

    components.queryItems = [
      URLQueryItem(name: "min_lat", value: String(region.center.latitude - latDelta)),
      URLQueryItem(name: "max_lat", value: String(region.center.latitude + latDelta)),
      URLQueryItem(name: "min_lon", value: String(region.center.longitude - lonDelta)),
      URLQueryItem(name: "max_lon", value: String(region.center.longitude + lonDelta)),
      URLQueryItem(name: "limit", value: "200"),
    ]

    guard let url = components.url else {
      throw NerveError.network(
        message: "Failed to construct URL from components: \(components)",
        reason: .other
      )
    }

    return url
  }

  // MARK: - Response Validation

  /// Validates the HTTP response and throws domain errors for non-success codes.
  ///
  /// Each error case populates ``NetworkErrorReason`` so that upstream callers
  /// (e.g. ``MapViewModel`` data pipeline) can make structured retry decisions
  /// via ``NetworkErrorReason/isRetryable`` instead of brittle string matching.
  private static func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NerveError.network(
        message: "Invalid response type — expected HTTPURLResponse.",
        reason: .other
      )
    }

    switch httpResponse.statusCode {
    case 200...299:
      return  // Success — no action needed.
    case 401, 403:
      throw NerveError.network(
        message: "Authentication failed (HTTP \(httpResponse.statusCode)).",
        reason: .unauthorized
      )
    case 404:
      throw NerveError.network(
        message: "Resource not found (HTTP 404).",
        reason: .notFound
      )
    case 429:
      throw NerveError.network(
        message: "Rate limited (HTTP 429). Retrying after backoff.",
        reason: .rateLimited
      )
    case 500...599:
      throw NerveError.network(
        message: "Server error (HTTP \(httpResponse.statusCode)).",
        reason: .serverError
      )
    default:
      throw NerveError.network(
        message: "Unexpected HTTP status \(httpResponse.statusCode).",
        reason: .other
      )
    }
  }

  // MARK: - Retry Classification

  /// Determines whether an error is transient and worth retrying.
  ///
  /// Uses structured ``NetworkErrorReason/isRetryable`` for `NerveError`
  /// classifications instead of brittle string matching.
  ///
  /// Retryable errors include:
  /// - URL timeouts and network connectivity issues
  /// - HTTP 429 (rate limited) and 5xx (server errors)
  ///
  /// Non-retryable errors include:
  /// - HTTP 401/403 (authentication — won't change on retry)
  /// - HTTP 404 (resource doesn't exist)
  /// - Decoding errors (response format won't change)
  private static func isRetryableError(_ error: any Error) -> Bool {
    // URLSession-level transient errors.
    if let urlError = error as? URLError {
      switch urlError.code {
      case .timedOut, .networkConnectionLost, .notConnectedToInternet,
        .cannotConnectToHost, .dnsLookupFailed:
        return true
      default:
        return false
      }
    }

    // NerveError classification — use structured reason for deterministic
    // retry decisions instead of string matching.
    if let nerveError = error as? NerveError {
      switch nerveError {
      case .network(_, let reason, _):
        return reason?.isRetryable ?? false
      default:
        return false
      }
    }

    return false
  }
}

// MARK: - DTO Types

/// API response envelope wrapping an array of news items.
///
/// Matches the expected JSON structure:
/// ```json
/// {
///   "items": [ ... ],
///   "total": 42,
///   "page": 1
/// }
/// ```
struct NewsResponseEnvelope: Decodable, Sendable {
  let items: [NewsItemDTO]
  let total: Int?
  let page: Int?
}

/// Data Transfer Object for a news item from the REST API.
///
/// Maps the API's JSON schema to a flat struct, then converts to
/// the canonical ``Core/NewsItem`` domain model via ``toDomainModel()``.
///
/// Keeping DTOs in `NetworkLayer` isolates JSON schema changes from
/// the rest of the codebase — only this file needs updating when
/// the API contract evolves.
struct NewsItemDTO: Decodable, Sendable {
  let id: String
  let headline: String
  let summary: String
  let source: String
  let articleUrl: String?
  let category: String
  let latitude: Double
  let longitude: Double
  let publishedAt: Date
  let imageUrl: String?

  /// Safe fallback coordinate for invalid API data.
  ///
  /// Defined as a `static let` to avoid force unwrap at the call site.
  /// `GeoCoordinate(latitude: 0, longitude: 0)` is always valid (Null Island),
  /// so the `!` is structurally safe — but a static constant is clearer intent.
  // swiftlint:disable:next force_unwrapping
  private static let fallbackCoordinate = GeoCoordinate(latitude: 0, longitude: 0)!

  /// Converts this DTO to the canonical domain model.
  ///
  /// Invalid coordinates or unknown categories fall back to safe defaults
  /// rather than crashing — the API contract may evolve independently.
  func toDomainModel() -> NewsItem {
    let coordinate = GeoCoordinate(latitude: latitude, longitude: longitude)
      ?? Self.fallbackCoordinate

    let newsCategory = NewsCategory(rawValue: category) ?? .other

    return NewsItem(
      id: id,
      headline: headline,
      summary: summary,
      source: source,
      articleURL: articleUrl.flatMap(URL.init(string:)),
      category: newsCategory,
      coordinate: coordinate,
      publishedAt: publishedAt,
      imageURL: imageUrl.flatMap(URL.init(string:)),
      analysis: nil
    )
  }
}
