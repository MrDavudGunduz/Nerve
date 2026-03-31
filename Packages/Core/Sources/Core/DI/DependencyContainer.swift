//
//  DependencyContainer.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

/// A lightweight, actor-based dependency injection container.
///
/// `DependencyContainer` provides thread-safe service registration and
/// resolution using Swift Concurrency. It supports three lifetime strategies:
///
/// - **Singleton:** A single shared instance is created on first resolve
///   and cached for all subsequent calls.
/// - **Transient:** A new instance is created on every resolve call.
/// - **Scoped:** A single instance is cached within a named scope.
///   When the scope is invalidated, the cached instance is discarded.
///
/// ## Usage
///
/// ```swift
/// let container = DependencyContainer()
///
/// await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
///   NewsAPIClient()
/// }
///
/// let newsService = try await container.resolve(NewsServiceProtocol.self)
/// ```
///
/// ## Named Registrations
///
/// Register multiple implementations of the same protocol:
///
/// ```swift
/// await container.register(NewsServiceProtocol.self, name: "production") {
///   ProductionNewsAPI()
/// }
/// await container.register(NewsServiceProtocol.self, name: "staging") {
///   StagingNewsAPI()
/// }
///
/// let api = try await container.resolve(NewsServiceProtocol.self, name: "production")
/// ```
///
/// ## Scoped Lifetimes
///
/// ```swift
/// await container.register(UserSession.self, lifetime: .scoped("auth")) {
///   UserSession()
/// }
///
/// // Later, when user logs out:
/// await container.invalidateScope("auth")
/// ```
///
/// ## Testing
///
/// Override registrations in test setup to inject mock implementations:
///
/// ```swift
/// await container.register(NewsServiceProtocol.self) {
///   MockNewsService()
/// }
/// ```
public actor DependencyContainer {

  // MARK: - Lifetime

  /// Defines how the container manages the lifecycle of a resolved dependency.
  public enum Lifetime: Sendable, Equatable {
    /// A single instance is created and reused across all resolve calls.
    case singleton
    /// A new instance is created for every resolve call.
    case transient
    /// A single instance is cached within the given scope name.
    /// Call ``DependencyContainer/invalidateScope(_:)`` to discard
    /// all cached instances in that scope.
    case scoped(String)
  }

  // MARK: - Registration Entry

  /// Internal storage for a single dependency registration.
  private struct Registration {
    let lifetime: Lifetime
    let factory: @Sendable () async throws -> any Sendable
    var cachedInstance: (any Sendable)?
  }

  // MARK: - Storage

  private var registrations: [ServiceKey: Registration] = [:]

  /// Keys currently being resolved — used to detect circular dependencies.
  private var resolvingKeys: Set<ServiceKey> = []

  // MARK: - Init

  /// Creates a new, empty dependency container.
  public init() {}

  // MARK: - Registration

  /// Registers a factory closure for the given type.
  ///
  /// If a registration already exists for this type and name combination,
  /// it will be replaced (useful for overriding with mocks in tests).
  ///
  /// - Parameters:
  ///   - type: The protocol or concrete type to register.
  ///   - name: Optional tag to distinguish multiple implementations
  ///     of the same protocol. Pass `nil` for the default registration.
  ///   - lifetime: The lifecycle strategy (`.singleton`, `.transient`,
  ///     or `.scoped("name")`).
  ///   - factory: A `Sendable` closure that produces an instance of `T`.
  public func register<T: Sendable>(
    _ type: T.Type,
    name: String? = nil,
    lifetime: Lifetime = .singleton,
    factory: @escaping @Sendable () async throws -> T
  ) {
    let key = ServiceKey(type, name: name)
    registrations[key] = Registration(
      lifetime: lifetime,
      factory: factory,
      cachedInstance: nil
    )
  }

  // MARK: - Resolution

  /// Resolves an instance of the given type from the container.
  ///
  /// - Parameters:
  ///   - type: The protocol or concrete type to resolve.
  ///   - name: Optional tag matching the name used during registration.
  /// - Returns: An instance of `T`.
  /// - Throws: `DependencyError.notRegistered` if no factory is registered,
  ///           `DependencyError.typeMismatch` if the factory produces the wrong type.
  public func resolve<T: Sendable>(
    _ type: T.Type,
    name: String? = nil
  ) async throws -> T {
    let key = ServiceKey(type, name: name)

    guard let registration = registrations[key] else {
      throw DependencyError.notRegistered(String(describing: type))
    }

    switch registration.lifetime {

    case .singleton, .scoped:
      // 1. Return cached instance immediately if available.
      if let cached = registration.cachedInstance {
        guard let instance = cached as? T else {
          throw DependencyError.typeMismatch(
            expected: String(describing: type),
            actual: String(describing: Swift.type(of: cached))
          )
        }
        return instance
      }

      // 2. Call the factory. Note: we intentionally do NOT use
      //    `resolvingKeys` here for singleton/scoped lifetimes.
      //    With actor reentrancy, a concurrent resolve arriving
      //    during the `await` below is a legitimate parallel call,
      //    not a circular dependency. The double-check in step 4
      //    ensures true singleton semantics by returning the first
      //    cached value when multiple factories race.
      let instance: any Sendable
      instance = try await registration.factory()

      // 3. Type-check the factory output.
      guard let typed = instance as? T else {
        throw DependencyError.typeMismatch(
          expected: String(describing: type),
          actual: String(describing: Swift.type(of: instance))
        )
      }

      // 4. Double-check after await: another concurrent resolve may
      //    have populated the cache during the suspension point above.
      //    If so, return the existing cached value for true singleton
      //    semantics. Otherwise, cache our result.
      if let alreadyCached = registrations[key]?.cachedInstance,
        let existing = alreadyCached as? T
      {
        return existing
      }

      registrations[key]?.cachedInstance = typed
      return typed

    case .transient:
      // Circular dependency detection for transient services.
      guard !resolvingKeys.contains(key) else {
        throw DependencyError.circularDependency(String(describing: type))
      }
      resolvingKeys.insert(key)
      defer { resolvingKeys.remove(key) }

      let instance = try await registration.factory()
      guard let typed = instance as? T else {
        throw DependencyError.typeMismatch(
          expected: String(describing: type),
          actual: String(describing: Swift.type(of: instance))
        )
      }
      return typed
    }
  }

  // MARK: - Scope Management

  /// Invalidates all cached instances belonging to the given scope.
  ///
  /// Registered factories are preserved — subsequent `resolve()` calls
  /// will create fresh instances. This is ideal for session-based
  /// lifecycles (e.g., user logout).
  ///
  /// ```swift
  /// await container.invalidateScope("auth")
  /// ```
  ///
  /// - Parameter scope: The scope name to invalidate.
  public func invalidateScope(_ scope: String) {
    for (key, var registration) in registrations {
      if case .scoped(let registeredScope) = registration.lifetime,
        registeredScope == scope
      {
        registration.cachedInstance = nil
        registrations[key] = registration
      }
    }
  }

  // MARK: - Utilities

  /// Returns `true` if a factory is registered for the given type and name.
  public func isRegistered<T>(_ type: T.Type, name: String? = nil) -> Bool {
    registrations[ServiceKey(type, name: name)] != nil
  }

  /// Removes all registrations and cached instances.
  ///
  /// Primarily intended for test teardown.
  public func reset() {
    registrations.removeAll()
  }

  /// The number of currently registered dependencies.
  public var registrationCount: Int {
    registrations.count
  }
}
