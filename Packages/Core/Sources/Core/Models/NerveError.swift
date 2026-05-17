//
//  NerveError.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

// MARK: - ErrorContext

/// Additional diagnostic information attached to a ``NerveError``.
///
/// Carries the original underlying error and the call-site location
/// to aid debugging and structured logging, without affecting equality
/// checks which compare only the error category and message.
public struct ErrorContext: Sendable {

  /// The original error that caused this ``NerveError``.
  public let underlyingError: (any Error)?

  /// The source file where the error was created.
  public let file: String

  /// The source line where the error was created.
  public let line: UInt

  /// Creates a diagnostic context for a `NerveError`.
  ///
  /// Typically called at the throw site:
  /// ```swift
  /// throw NerveError.storage(
  ///   message: "Insert failed",
  ///   context: ErrorContext(underlyingError: swiftDataError)
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - underlyingError: The original error, for upstream diagnostics.
  ///   - file: Automatically captured source file name.
  ///   - line: Automatically captured source line number.
  public init(
    underlyingError: (any Error)? = nil,
    file: String = #file,
    line: UInt = #line
  ) {
    self.underlyingError = underlyingError
    self.file = file
    self.line = line
  }
}

// MARK: - NetworkErrorReason

/// Structured classification of network failure modes.
///
/// Enables pattern-matching in retry logic instead of brittle string comparisons.
/// Use in combination with ``NerveError/network(message:reason:context:)``
/// for deterministic retry decisions.
///
/// ```swift
/// case .network(_, let reason, _) where reason?.isRetryable == true:
///   // safe to retry
/// ```
public enum NetworkErrorReason: String, Sendable, Codable, Equatable {
  /// HTTP 429 Too Many Requests — the server is rate-limiting the client.
  case rateLimited
  /// HTTP 5xx — a transient server-side failure.
  case serverError
  /// The request did not complete within the configured timeout interval.
  case timeout
  /// The device has no active network connection.
  case noConnection
  /// The network connection was lost mid-request.
  case connectionLost
  /// HTTP 401/403 — the request lacks valid authentication credentials.
  case unauthorized
  /// HTTP 404 — the requested resource does not exist.
  case notFound
  /// A failure that does not fit any other category.
  case other

  /// Whether this error reason is transient and safe to retry with backoff.
  public var isRetryable: Bool {
    switch self {
    case .rateLimited, .serverError, .timeout, .connectionLost:
      return true
    case .noConnection, .unauthorized, .notFound, .other:
      return false
    }
  }
}

// MARK: - NerveError

/// A unified error type for all recoverable failures across Nerve modules.
///
/// Throw `NerveError` from any service layer and catch it in the ViewModel
/// or UI. Each case carries a human-readable `message` and an optional
/// ``ErrorContext`` for structured diagnostic logging.
///
/// ```swift
/// throw NerveError.network(
///   message: "Request timed out after 30s",
///   reason: .timeout,
///   context: ErrorContext(underlyingError: urlError)
/// )
/// ```
///
/// `Equatable` conformance compares only the case and message,
/// ignoring `ErrorContext` (which wraps a non-equatable `any Error`).
public enum NerveError: Error, Sendable {

  /// A network request failed.
  ///
  /// - Parameters:
  ///   - message: Human-readable description of the failure.
  ///   - reason: Structured classification for retry logic.
  ///   - context: Optional diagnostic context.
  case network(message: String, reason: NetworkErrorReason? = nil, context: ErrorContext? = nil)

  /// A persistence or storage operation failed.
  case storage(message: String, context: ErrorContext? = nil)

  /// An AI inference operation failed.
  case ai(message: String, context: ErrorContext? = nil)

  /// A location services operation failed.
  case location(message: String, context: ErrorContext? = nil)

  /// A dependency could not be resolved from the container.
  case dependency(message: String, context: ErrorContext? = nil)

  /// An unexpected error that doesn't fit other categories.
  case unknown(message: String, context: ErrorContext? = nil)
}

// MARK: - Equatable

extension NerveError: Equatable {
  public static func == (lhs: NerveError, rhs: NerveError) -> Bool {
    switch (lhs, rhs) {
    case (.network(let lMsg, let lReason, _), .network(let rMsg, let rReason, _)):
      return lMsg == rMsg && lReason == rReason
    case (.storage(let lMsg, _), .storage(let rMsg, _)):
      return lMsg == rMsg
    case (.ai(let lMsg, _), .ai(let rMsg, _)):
      return lMsg == rMsg
    case (.location(let lMsg, _), .location(let rMsg, _)):
      return lMsg == rMsg
    case (.dependency(let lMsg, _), .dependency(let rMsg, _)):
      return lMsg == rMsg
    case (.unknown(let lMsg, _), .unknown(let rMsg, _)):
      return lMsg == rMsg
    case (.network, _), (.storage, _), (.ai, _),
      (.location, _), (.dependency, _), (.unknown, _):
      return false
    }
  }
}

// MARK: - LocalizedError

/// Provides a **user-facing** `errorDescription` suitable for display in UI banners.
///
/// Keep these messages concise and non-technical. For structured log output,
/// use ``debugDescription`` which includes the full underlying detail.
extension NerveError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .network: return "A network error occurred. Please check your connection."
    case .storage: return "A local storage error occurred. Please restart the app."
    case .ai: return "Analysis could not be completed."
    case .location: return "Location services are unavailable."
    case .dependency: return "An internal configuration error occurred."
    case .unknown: return "An unexpected error occurred."
    }
  }
}

// MARK: - CustomDebugStringConvertible

/// Provides the full technical error detail used exclusively in `os_log` and Instruments.
extension NerveError: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .network(let message, let reason, _):
      let suffix = reason.map { " (reason: \($0.rawValue))" } ?? ""
      return "[NerveError.network] \(message)\(suffix)"
    case .storage(let message, _): return "[NerveError.storage] \(message)"
    case .ai(let message, _): return "[NerveError.ai] \(message)"
    case .location(let message, _): return "[NerveError.location] \(message)"
    case .dependency(let message, _): return "[NerveError.dependency] \(message)"
    case .unknown(let message, _): return "[NerveError.unknown] \(message)"
    }
  }
}
