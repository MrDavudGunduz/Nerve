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

// MARK: - NerveError

/// A unified error type for all recoverable errors across Nerve modules.
///
/// Each case wraps a descriptive message and an optional ``ErrorContext``
/// that preserves the original underlying error for diagnostics.
///
/// `Equatable` conformance compares only the case and message,
/// ignoring the context (which contains non-equatable `any Error`).
public enum NerveError: Error, Sendable {

  /// A network request failed.
  case network(message: String, context: ErrorContext? = nil)

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
    case (.network(let lMsg, _), .network(let rMsg, _)):
      return lMsg == rMsg
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
    default:
      return false
    }
  }
}

// MARK: - LocalizedError

extension NerveError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .network(let message, _):
      return "Network error: \(message)"
    case .storage(let message, _):
      return "Storage error: \(message)"
    case .ai(let message, _):
      return "AI analysis error: \(message)"
    case .location(let message, _):
      return "Location error: \(message)"
    case .dependency(let message, _):
      return "Dependency error: \(message)"
    case .unknown(let message, _):
      return "Unexpected error: \(message)"
    }
  }
}
