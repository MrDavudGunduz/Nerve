//
//  SwiftDataStorageService.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation
import SwiftData

// MARK: - SwiftDataStorageService

/// Concrete implementation of ``StorageServiceProtocol`` backed by SwiftData.
///
/// All persistence operations are delegated to ``PersistenceActor``, which
/// owns the `ModelContext` and serializes access. This type is a thin
/// `Sendable` facade that is safe to inject into any Swift Concurrency context.
///
/// ## Setup
///
/// ```swift
/// let service = SwiftDataStorageService(
///     persistenceActor: PersistenceActor(modelContainer: sharedContainer)
/// )
/// await container.register(StorageServiceProtocol.self, lifetime: .singleton) {
///     service
/// }
/// ```
public struct SwiftDataStorageService: StorageServiceProtocol {

  // MARK: - Dependencies

  private let actor: PersistenceActor

  // MARK: - Init

  /// Creates a storage service backed by the given persistence actor.
  ///
  /// - Parameter persistenceActor: The actor that owns the SwiftData `ModelContext`.
  public init(persistenceActor: PersistenceActor) {
    self.actor = persistenceActor
  }

  // MARK: - StorageServiceProtocol

  /// Persists an array of news items using an upsert strategy.
  ///
  /// Items with matching IDs are updated; new items are inserted.
  /// All changes are saved atomically at the end of the batch.
  ///
  /// - Parameter items: The news items to persist.
  /// - Throws: ``NerveError/storage(message:context:)`` if the save fails.
  public func saveNews(_ items: [NewsItem]) async throws {
    do {
      try await actor.save(items)
    } catch {
      throw NerveError.storage(
        message: "saveNews failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  /// Fetches persisted news items, optionally filtered by region and paginated.
  ///
  /// Results are sorted by `publishedAt` descending (newest first).
  ///
  /// - Parameters:
  ///   - region: Optional geographic filter (bounding box approximation). Pass `nil` for all.
  ///   - limit: Maximum number of items to return. Pass `nil` for no limit.
  ///   - offset: Number of items to skip. Pass `nil` or `0` to start from the beginning.
  /// - Returns: Matching ``NewsItem`` instances.
  /// - Throws: ``NerveError/storage(message:context:)`` on fetch failure.
  public func fetchNews(
    in region: GeoRegion?,
    limit: Int?,
    offset: Int?
  ) async throws -> [NewsItem] {
    do {
      return try await actor.fetch(in: region, limit: limit, offset: offset)
    } catch {
      throw NerveError.storage(
        message: "fetchNews failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  /// Deletes a news item by its unique identifier.
  ///
  /// - Parameter id: The ID of the item to remove.
  /// - Throws: ``NerveError/storage(message:context:)`` if the delete fails.
  public func deleteNews(id: String) async throws {
    do {
      try await actor.delete(id: id)
    } catch {
      throw NerveError.storage(
        message: "deleteNews(id: '\(id)') failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  /// Removes all cached items that have exceeded the 24-hour TTL.
  ///
  /// Safe to call from a background refresh task. If no items are expired,
  /// this is a fast no-op (no save round-trip).
  ///
  /// - Throws: ``NerveError/storage(message:context:)`` if the prune fails.
  public func pruneExpiredCache() async throws {
    do {
      try await actor.pruneExpired()
    } catch {
      throw NerveError.storage(
        message: "pruneExpiredCache failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }
}
