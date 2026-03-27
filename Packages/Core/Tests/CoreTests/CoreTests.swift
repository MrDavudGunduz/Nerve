import Foundation
import Testing

@testable import Core

// MARK: - Test Helpers

/// A mock service conforming to `Sendable` for DI container testing.
protocol MockServiceProtocol: Sendable {
  var identifier: String { get }
}

/// A concrete mock service used in registration/resolution tests.
struct MockService: MockServiceProtocol {
  let identifier: String

  init(identifier: String = "default") {
    self.identifier = identifier
  }
}

/// Thread-safe counter for transient service tests.
actor Counter {
  private var value = 0
  func increment() -> Int {
    value += 1
    return value
  }
}

/// A second mock protocol to test multiple registrations.
protocol AnotherMockProtocol: Sendable {
  var value: Int { get }
}

struct AnotherMockService: AnotherMockProtocol {
  let value: Int
}

// MARK: - DependencyContainer Tests

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
    // Singleton: both calls return the same cached instance
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

    // Transient: factory called each time, producing unique instances
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

    // Override with new factory
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

    // Scoped: same instance returned while scope is valid
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

    // Invalidate scope — next resolve should create a new instance
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

// MARK: - Domain Model Tests

@Suite("Domain Model Tests")
struct DomainModelTests {

  @Test("NewsItem is correctly initialized with all fields")
  func newsItemInit() {
    let coordinate = GeoCoordinate(latitude: 41.0082, longitude: 28.9784)
    let item = NewsItem(
      id: "test-1",
      headline: "Breaking News",
      summary: "A test summary",
      source: "Test Source",
      category: .technology,
      coordinate: coordinate,
      publishedAt: Date(timeIntervalSince1970: 0)
    )

    #expect(item.id == "test-1")
    #expect(item.headline == "Breaking News")
    #expect(item.category == .technology)
    #expect(item.coordinate == coordinate)
    #expect(item.analysis == nil)
  }

  @Test("HeadlineAnalysis credibility label boundaries")
  func credibilityLabels() {
    let verified = HeadlineAnalysis(
      clickbaitScore: 0.1, sentiment: .neutral, confidence: 0.9
    )
    #expect(verified.credibilityLabel == .verified)

    let caution = HeadlineAnalysis(
      clickbaitScore: 0.5, sentiment: .neutral, confidence: 0.8
    )
    #expect(caution.credibilityLabel == .caution)

    let clickbait = HeadlineAnalysis(
      clickbaitScore: 0.85, sentiment: .negative, confidence: 0.95
    )
    #expect(clickbait.credibilityLabel == .clickbait)
  }

  @Test("GeoRegion equality")
  func geoRegionEquality() {
    let region1 = GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0),
      radiusMeters: 1000
    )
    let region2 = GeoRegion(
      center: GeoCoordinate(latitude: 41.0, longitude: 29.0),
      radiusMeters: 1000
    )

    #expect(region1 == region2)
  }

  @Test("NewsCategory has expected case count")
  func newsCategoryCases() {
    #expect(NewsCategory.allCases.count == 9)
  }

  @Test("Sentiment has all expected cases")
  func sentimentCases() {
    #expect(Sentiment.allCases.count == 3)
    #expect(Sentiment.allCases.contains(.positive))
    #expect(Sentiment.allCases.contains(.neutral))
    #expect(Sentiment.allCases.contains(.negative))
  }
}

// MARK: - Core Module Tests

@Suite("Core Module Tests")
struct CoreModuleTests {

  @Test("Core module version is defined")
  func moduleVersion() {
    #expect(!Core.version.isEmpty)
  }

  @Test("Core.container is accessible")
  func sharedContainer() async {
    let isRegistered = await Core.container.isRegistered(MockServiceProtocol.self)
    #expect(isRegistered == false)
  }
}

// MARK: - DependencyError Tests

@Suite("DependencyError Tests")
struct DependencyErrorTests {

  @Test("notRegistered has descriptive message")
  func notRegisteredDescription() {
    let error = DependencyError.notRegistered("MockService")
    #expect(error.description.contains("MockService"))
    #expect(error.description.contains("No registration found"))
  }

  @Test("typeMismatch has descriptive message")
  func typeMismatchDescription() {
    let error = DependencyError.typeMismatch(expected: "String", actual: "Int")
    #expect(error.description.contains("String"))
    #expect(error.description.contains("Int"))
  }

  @Test("DependencyError conforms to Equatable")
  func equatable() {
    let a = DependencyError.notRegistered("Foo")
    let b = DependencyError.notRegistered("Foo")
    let c = DependencyError.notRegistered("Bar")

    #expect(a == b)
    #expect(a != c)
  }
}
