import Foundation
import Testing

@testable import Core

@Suite("DependencyContainer Tests")
struct DependencyContainerTests {

  let container = DependencyContainer()

  // MARK: - Registration & Resolution

  @Test("Registers and resolves a singleton service")
  func singletonResolution() async throws {
    await container.register(MockServiceProtocol.self, lifetime: .singleton) {
      MockService(identifier: "singleton-1")
    }

    let first = try await container.resolve(MockServiceProtocol.self)
    let second = try await container.resolve(MockServiceProtocol.self)

    #expect(first.identifier == "singleton-1")
    #expect(second.identifier == "singleton-1")
    #expect(first.identifier == second.identifier)
  }

  @Test("Registers and resolves a transient service")
  func transientResolution() async throws {
    let counter = Counter()

    await container.register(MockServiceProtocol.self, lifetime: .transient) {
      let current = await counter.increment()
      return MockService(identifier: "transient-\(current)")
    }

    let first = try await container.resolve(MockServiceProtocol.self)
    let second = try await container.resolve(MockServiceProtocol.self)

    #expect(first.identifier != second.identifier)
  }

  @Test("Resolves multiple independent registrations")
  func multipleRegistrations() async throws {
    await container.register(MockServiceProtocol.self) {
      MockService(identifier: "service-A")
    }
    await container.register(AnotherMockProtocol.self) {
      AnotherMockService(value: 42)
    }

    let serviceA = try await container.resolve(MockServiceProtocol.self)
    let serviceB = try await container.resolve(AnotherMockProtocol.self)

    #expect(serviceA.identifier == "service-A")
    #expect(serviceB.value == 42)
  }

  // MARK: - Error Handling

  @Test("Throws notRegistered when resolving an unregistered type")
  func unregisteredResolution() async {
    await #expect(throws: DependencyError.self) {
      try await container.resolve(MockServiceProtocol.self)
    }
  }

  // MARK: - Override

  @Test("Override replaces previous registration")
  func overrideRegistration() async throws {
    await container.register(MockServiceProtocol.self) {
      MockService(identifier: "original")
    }

    let original = try await container.resolve(MockServiceProtocol.self)
    #expect(original.identifier == "original")

    await container.register(MockServiceProtocol.self) {
      MockService(identifier: "overridden")
    }

    let overridden = try await container.resolve(MockServiceProtocol.self)
    #expect(overridden.identifier == "overridden")
  }

  // MARK: - Reset

  @Test("Reset clears all registrations")
  func resetClearsAll() async throws {
    await container.register(MockServiceProtocol.self) {
      MockService()
    }

    let countBefore = await container.registrationCount
    #expect(countBefore == 1)

    await container.reset()

    let countAfter = await container.registrationCount
    #expect(countAfter == 0)

    await #expect(throws: DependencyError.self) {
      try await container.resolve(MockServiceProtocol.self)
    }
  }

  // MARK: - Utility

  @Test("isRegistered returns correct state")
  func isRegisteredCheck() async {
    let before = await container.isRegistered(MockServiceProtocol.self)
    #expect(before == false)

    await container.register(MockServiceProtocol.self) {
      MockService()
    }

    let after = await container.isRegistered(MockServiceProtocol.self)
    #expect(after == true)
  }

  // MARK: - Scoped Lifetime

  @Test("Scoped service caches within the same scope")
  func scopedCaching() async throws {
    await container.register(MockServiceProtocol.self, lifetime: .scoped("auth")) {
      MockService(identifier: "session-user")
    }

    let first = try await container.resolve(MockServiceProtocol.self)
    let second = try await container.resolve(MockServiceProtocol.self)

    #expect(first.identifier == second.identifier)
    #expect(first.identifier == "session-user")
  }

  @Test("invalidateScope clears cached instance and creates fresh one")
  func scopeInvalidation() async throws {
    let counter = Counter()

    await container.register(MockServiceProtocol.self, lifetime: .scoped("auth")) {
      let current = await counter.increment()
      return MockService(identifier: "session-\(current)")
    }

    let first = try await container.resolve(MockServiceProtocol.self)
    #expect(first.identifier == "session-1")

    await container.invalidateScope("auth")

    let second = try await container.resolve(MockServiceProtocol.self)
    #expect(second.identifier == "session-2")
  }

  // MARK: - Named Registrations

  @Test("Named registrations resolve independently")
  func namedResolution() async throws {
    await container.register(MockServiceProtocol.self, name: "production") {
      MockService(identifier: "prod-api")
    }
    await container.register(MockServiceProtocol.self, name: "staging") {
      MockService(identifier: "staging-api")
    }

    let prod = try await container.resolve(MockServiceProtocol.self, name: "production")
    let staging = try await container.resolve(MockServiceProtocol.self, name: "staging")

    #expect(prod.identifier == "prod-api")
    #expect(staging.identifier == "staging-api")
  }

  @Test("Named registration does not interfere with default")
  func namedAndDefaultCoexist() async throws {
    await container.register(MockServiceProtocol.self) {
      MockService(identifier: "default")
    }
    await container.register(MockServiceProtocol.self, name: "special") {
      MockService(identifier: "special")
    }

    let defaultService = try await container.resolve(MockServiceProtocol.self)
    let specialService = try await container.resolve(MockServiceProtocol.self, name: "special")

    #expect(defaultService.identifier == "default")
    #expect(specialService.identifier == "special")
    #expect(await container.registrationCount == 2)
  }
}
