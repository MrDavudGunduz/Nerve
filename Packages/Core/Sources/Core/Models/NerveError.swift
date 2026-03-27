//
//  NerveError.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// A unified error type for all recoverable errors across Nerve modules.
///
/// Each case wraps a more specific underlying error to preserve the original
/// context while providing a consistent API for error handling at the UI layer.
public enum NerveError: Error, Sendable, Equatable {

  /// A network request failed.
  case network(message: String)

  /// A persistence or storage operation failed.
  case storage(message: String)

  /// An AI inference operation failed.
  case ai(message: String)

  /// A location services operation failed.
  case location(message: String)

  /// A dependency could not be resolved from the container.
  case dependency(message: String)

  /// An unexpected error that doesn't fit other categories.
  case unknown(message: String)
}

extension NerveError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .network(let message):
      return "Network error: \(message)"
    case .storage(let message):
      return "Storage error: \(message)"
    case .ai(let message):
      return "AI analysis error: \(message)"
    case .location(let message):
      return "Location error: \(message)"
    case .dependency(let message):
      return "Dependency error: \(message)"
    case .unknown(let message):
      return "Unexpected error: \(message)"
    }
  }
}
