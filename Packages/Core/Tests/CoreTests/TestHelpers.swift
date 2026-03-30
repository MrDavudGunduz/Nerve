import Foundation
import Testing

@testable import Core

// MARK: - Mock Protocols

/// A mock service conforming to `Sendable` for DI container testing.
protocol MockServiceProtocol: Sendable {
  var identifier: String { get }
}

/// A second mock protocol to test multiple registrations.
protocol AnotherMockProtocol: Sendable {
  var value: Int { get }
}

// MARK: - Mock Implementations

/// A concrete mock service used in registration/resolution tests.
struct MockService: MockServiceProtocol {
  let identifier: String

  init(identifier: String = "default") {
    self.identifier = identifier
  }
}

struct AnotherMockService: AnotherMockProtocol {
  let value: Int
}

// MARK: - Utilities

/// Thread-safe counter for transient service tests.
actor Counter {
  private var value = 0
  func increment() -> Int {
    value += 1
    return value
  }
}
