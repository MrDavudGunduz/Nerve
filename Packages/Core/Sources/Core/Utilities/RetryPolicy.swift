//
//  RetryPolicy.swift
//  Core
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Foundation
import OSLog

// MARK: - RetryPolicy

/// A reusable exponential backoff retry policy for transient failures.
///
/// Designed for network operations, storage writes, or any async work
/// that may fail transiently. The delay between attempts grows
/// exponentially with optional jitter to avoid thundering-herd effects.
///
/// ## Configuration
///
/// | Parameter | Default | Description |
/// |-----------|---------|-------------|
/// | `maxAttempts` | 3 | Total attempts (including the initial try) |
/// | `baseDelay` | 1.0s | Delay before the first retry |
/// | `multiplier` | 2.0 | Delay multiplier after each failure |
/// | `maxDelay` | 30.0s | Upper bound on computed delay |
/// | `jitterFactor` | 0.25 | Random ±25% variation on each delay |
///
/// ## Usage
///
/// ```swift
/// let result = try await RetryPolicy.execute(maxAttempts: 3) {
///   try await networkClient.fetchData(from: url)
/// }
/// ```
///
/// ## Retry Decision
///
/// By default, all errors trigger a retry. Supply a custom `shouldRetry`
/// closure to filter:
///
/// ```swift
/// let data = try await RetryPolicy.execute(
///   shouldRetry: { error in
///     (error as? URLError)?.code == .timedOut
///   }
/// ) {
///   try await session.data(from: url)
/// }
/// ```
public enum RetryPolicy: Sendable {

  // MARK: - Configuration

  /// Default maximum number of attempts (1 initial + 2 retries).
  public static let defaultMaxAttempts = 3

  /// Default base delay in seconds before the first retry.
  public static let defaultBaseDelay: TimeInterval = 1.0

  /// Default delay multiplier (exponential growth).
  public static let defaultMultiplier: Double = 2.0

  /// Default maximum delay cap in seconds.
  public static let defaultMaxDelay: TimeInterval = 30.0

  /// Default jitter factor (±25% randomization).
  public static let defaultJitterFactor: Double = 0.25

  // MARK: - Logging

  private static let logger = Logger(
    subsystem: LogSubsystem.main,
    category: "RetryPolicy"
  )

  // MARK: - Execute

  /// Executes an async throwing operation with exponential backoff retry.
  ///
  /// The operation is attempted up to `maxAttempts` times. If all attempts
  /// fail, the error from the **last** attempt is thrown.
  ///
  /// - Parameters:
  ///   - maxAttempts: Total number of attempts (default: 3).
  ///   - baseDelay: Initial delay in seconds (default: 1.0).
  ///   - multiplier: Delay growth factor (default: 2.0).
  ///   - maxDelay: Upper bound on delay (default: 30.0).
  ///   - jitterFactor: Random variation factor (default: 0.25).
  ///   - shouldRetry: Closure that determines if a given error warrants
  ///     a retry. Defaults to always retrying. Return `false` for
  ///     non-retryable errors (e.g., 404 Not Found).
  ///   - operation: The async throwing operation to execute.
  /// - Returns: The result of the successful operation.
  /// - Throws: The error from the last failed attempt, or `CancellationError`
  ///   if the task is cancelled during a retry delay.
  public static func execute<T: Sendable>(
    maxAttempts: Int = defaultMaxAttempts,
    baseDelay: TimeInterval = defaultBaseDelay,
    multiplier: Double = defaultMultiplier,
    maxDelay: TimeInterval = defaultMaxDelay,
    jitterFactor: Double = defaultJitterFactor,
    shouldRetry: @Sendable (any Error) -> Bool = { _ in true },
    operation: @Sendable () async throws -> T
  ) async throws -> T {
    var lastError: (any Error)?
    var currentDelay = baseDelay

    for attempt in 1...maxAttempts {
      // Check for task cancellation before each attempt.
      try Task.checkCancellation()

      do {
        return try await operation()
      } catch {
        lastError = error

        // Don't retry if cancelled or on the last attempt.
        guard attempt < maxAttempts else { break }

        // Check if the error is retryable.
        guard shouldRetry(error) else {
          logger.info(
            """
            Retry skipped: error is not retryable \
            (attempt \(attempt)/\(maxAttempts)): \
            \(error.localizedDescription, privacy: .public)
            """
          )
          break
        }

        // Server-directed delay takes precedence over computed backoff.
        // When the server sends a `Retry-After` header (attached to
        // `NerveError.network` via the `retryAfter` field), use that
        // value directly — it reflects the server's actual rate-limit
        // window. Falls back to exponential backoff with jitter when
        // the server provides no recommendation.
        let delay: TimeInterval
        if let serverDelay = Self.extractRetryAfter(from: error) {
          delay = min(serverDelay, maxDelay)
          logger.info(
            """
            Retry \(attempt)/\(maxAttempts) failed: \
            \(error.localizedDescription, privacy: .public). \
            Using server-provided Retry-After: \(String(format: "%.1f", delay))s.
            """
          )
        } else {
          // Compute jittered delay.
          let jitter = currentDelay * Double.random(in: -jitterFactor...jitterFactor)
          delay = min(currentDelay + jitter, maxDelay)
          logger.info(
            """
            Retry \(attempt)/\(maxAttempts) failed: \
            \(error.localizedDescription, privacy: .public). \
            Retrying in \(String(format: "%.2f", delay))s…
            """
          )
        }

        // Sleep using Duration API (replaces deprecated nanosecond-based sleep).
        try await Task.sleep(for: .seconds(delay))

        // Grow the delay for the next iteration.
        currentDelay = min(currentDelay * multiplier, maxDelay)
      }
    }

    // All attempts exhausted — throw the last error.
    throw lastError ?? CancellationError()
  }

  // MARK: - Convenience

  /// Computes the delay for a specific attempt number (0-indexed).
  ///
  /// Useful for testing or UI display ("Retrying in Xs…").
  ///
  /// - Parameters:
  ///   - attempt: The 0-based attempt index.
  ///   - baseDelay: Base delay in seconds.
  ///   - multiplier: Growth factor.
  ///   - maxDelay: Upper bound.
  /// - Returns: The computed delay in seconds (without jitter).
  public static func delay(
    forAttempt attempt: Int,
    baseDelay: TimeInterval = defaultBaseDelay,
    multiplier: Double = defaultMultiplier,
    maxDelay: TimeInterval = defaultMaxDelay
  ) -> TimeInterval {
    let computed = baseDelay * pow(multiplier, Double(attempt))
    return min(computed, maxDelay)
  }

  // MARK: - Retry-After Extraction

  /// Extracts the server-directed retry delay from a ``NerveError``.
  ///
  /// When the error is a ``NerveError/network(message:reason:retryAfter:context:)``
  /// with a non-nil `retryAfter` value, that value is returned. For all other
  /// error types, returns `nil` — the caller should fall back to computed backoff.
  ///
  /// - Parameter error: The error to inspect.
  /// - Returns: The server-suggested retry delay, or `nil`.
  private static func extractRetryAfter(from error: any Error) -> TimeInterval? {
    guard let nerveError = error as? NerveError else { return nil }
    switch nerveError {
    case .network(_, _, let retryAfter, _):
      return retryAfter
    default:
      return nil
    }
  }
}
