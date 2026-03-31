import Foundation
import Testing

@testable import Core

// MARK: - Circular Dependency Tests

@Suite("Circular Dependency Tests")
struct CircularDependencyTests {

  let container = DependencyContainer()

  @Test("Detects self-referencing circular dependency for transient lifetime")
  func selfReferencing() async throws {
    await container.register(MockServiceProtocol.self, lifetime: .transient) { [container] in
      _ = try await container.resolve(MockServiceProtocol.self)
      return MockService(identifier: "should-not-reach")
    }

    await #expect(throws: DependencyError.self) {
      try await container.resolve(MockServiceProtocol.self)
    }
  }

  @Test("Non-circular resolution succeeds normally")
  func nonCircular() async throws {
    await container.register(MockServiceProtocol.self) {
      MockService(identifier: "no-cycle")
    }

    let service = try await container.resolve(MockServiceProtocol.self)
    #expect(service.identifier == "no-cycle")
  }
}

// MARK: - Concurrent Resolution Tests

@Suite("Concurrent Resolution Tests")
struct ConcurrentResolutionTests {

  let container = DependencyContainer()

  @Test("Concurrent singleton resolution returns consistent results")
  func concurrentSingleton() async throws {
    await container.register(MockServiceProtocol.self, lifetime: .singleton) {
      MockService(identifier: "concurrent-singleton")
    }

    let results = try await withThrowingTaskGroup(
      of: String.self,
      returning: [String].self
    ) { group in
      for _ in 0..<10 {
        group.addTask {
          let service = try await container.resolve(MockServiceProtocol.self)
          return service.identifier
        }
      }
      var collected: [String] = []
      for try await id in group {
        collected.append(id)
      }
      return collected
    }

    #expect(results.count == 10)
    #expect(results.allSatisfy { $0 == "concurrent-singleton" })
  }

  @Test("Singleton resolved after first creation returns cached instance")
  func singletonDoubleCheckAfterAwait() async throws {
    let counter = Counter()

    await container.register(MockServiceProtocol.self, lifetime: .singleton) {
      let count = await counter.increment()
      return MockService(identifier: "created-\(count)")
    }

    // First resolve: creates the instance
    let first = try await container.resolve(MockServiceProtocol.self)
    #expect(first.identifier == "created-1")

    // Second resolve: should return cached instance, not call factory again
    let second = try await container.resolve(MockServiceProtocol.self)
    #expect(second.identifier == "created-1")
    #expect(first.identifier == second.identifier)
  }
}

// MARK: - Factory Error Tests

@Suite("Factory Error Tests")
struct FactoryErrorTests {

  let container = DependencyContainer()

  @Test("Factory throwing error propagates through resolve")
  func factoryError() async {
    await container.register(MockServiceProtocol.self) {
      throw NerveError.network(message: "simulated failure")
    }

    await #expect(throws: NerveError.self) {
      try await container.resolve(MockServiceProtocol.self)
    }
  }

  @Test("Async factory resolves correctly")
  func asyncFactory() async throws {
    await container.register(MockServiceProtocol.self) {
      try await Task.sleep(for: .milliseconds(1))
      return MockService(identifier: "async-result")
    }

    let service = try await container.resolve(MockServiceProtocol.self)
    #expect(service.identifier == "async-result")
  }
}
