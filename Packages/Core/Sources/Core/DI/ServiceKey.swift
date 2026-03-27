//
//  ServiceKey.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

/// A type-erased key for service registration in the DI container.
///
/// Uses `ObjectIdentifier` for O(1) hash-based lookup against
/// the registered protocol or concrete type.
/// Supports optional ``name`` for tagged registrations when multiple
/// implementations of the same protocol are needed.
///
/// ## Named Registrations
///
/// ```swift
/// await container.register(NewsServiceProtocol.self, name: "production") {
///   ProductionNewsAPI()
/// }
/// await container.register(NewsServiceProtocol.self, name: "staging") {
///   StagingNewsAPI()
/// }
/// ```
struct ServiceKey: Hashable, Sendable {

  private let identifier: ObjectIdentifier
  private let name: String?

  /// Creates a key from a metatype, e.g. `ServiceKey(NewsServiceProtocol.self)`.
  init<T>(_ type: T.Type, name: String? = nil) {
    self.identifier = ObjectIdentifier(type)
    self.name = name
  }
}
