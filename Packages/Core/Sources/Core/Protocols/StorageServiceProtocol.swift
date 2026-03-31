//
//  StorageServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for local data persistence.
///
/// Concrete implementations use SwiftData in `StorageLayer` behind
/// a `PersistenceActor` for thread-safe database access.
public protocol StorageServiceProtocol: Sendable {

  /// Persists an array of news items using an upsert strategy.
  ///
  /// Items with matching IDs are updated; new items are inserted.
  ///
  /// - Parameter items: The news items to save.
  func saveNews(_ items: [NewsItem]) async throws

  /// Fetches stored news items, optionally filtered by region and paginated.
  ///
  /// - Parameters:
  ///   - region: Optional region to filter results. Pass `nil` to fetch all.
  ///   - limit: Maximum number of items to return. Pass `nil` for no limit.
  ///   - offset: Number of items to skip before returning results.
  ///     Pass `nil` or `0` to start from the beginning.
  /// - Returns: An array of persisted ``NewsItem`` instances.
  func fetchNews(
    in region: GeoRegion?,
    limit: Int?,
    offset: Int?
  ) async throws -> [NewsItem]

  /// Deletes a news item by its unique identifier.
  ///
  /// - Parameter id: The ID of the item to remove.
  func deleteNews(id: String) async throws

  /// Removes all cached data that has exceeded its time-to-live.
  func pruneExpiredCache() async throws
}
