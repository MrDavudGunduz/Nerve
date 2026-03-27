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

  /// Fetches all stored news items within the given region.
  ///
  /// - Parameter region: Optional region to filter results.
  /// - Returns: An array of persisted ``NewsItem`` instances.
  func fetchNews(in region: GeoRegion?) async throws -> [NewsItem]

  /// Deletes a news item by its unique identifier.
  ///
  /// - Parameter id: The ID of the item to remove.
  func deleteNews(id: String) async throws

  /// Removes all cached data that has exceeded its time-to-live.
  func pruneExpiredCache() async throws
}
