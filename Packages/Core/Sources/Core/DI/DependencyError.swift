//
//  DependencyError.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

/// Errors thrown by the ``DependencyContainer`` during resolution.
public enum DependencyError: Error, Sendable, Equatable {
  /// No factory has been registered for the requested type.
  case notRegistered(String)
  /// The factory produced an instance of an unexpected type.
  case typeMismatch(expected: String, actual: String)
}

extension DependencyError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .notRegistered(let type):
      return "DependencyError: No registration found for '\(type)'. "
        + "Did you forget to call container.register(\(type).self, ...)?"
    case .typeMismatch(let expected, let actual):
      return "DependencyError: Expected '\(expected)' but factory produced '\(actual)'."
    }
  }
}
