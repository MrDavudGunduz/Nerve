//
//  PersistenceActor.swift
//  StorageLayer
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation
import OSLog
import SwiftData

// MARK: - PersistenceActor

/// A Swift actor that serializes all SwiftData read/write operations.
///
/// ## Why an Actor?
///
/// `ModelContext` is **not** `Sendable`. Accessing it from multiple Swift
/// Tasks concurrently leads to data races. By isolating the `ModelContext`
/// inside an actor, all operations are automatically serialized on a single
/// serial executor — eliminating the need for additional locks or queues.
///
/// ## Usage
///
/// ```swift
/// let actor = PersistenceActor(modelContainer: sharedContainer)
/// try await actor.save(items)
/// let news = try await actor.fetch(in: region, limit: 50)
/// ```
///
/// `PersistenceActor` is the implementation detail behind ``SwiftDataStorageService``.
/// External code should always interact via ``StorageServiceProtocol``.
public actor PersistenceActor {

  // MARK: - Properties

  private let modelContext: ModelContext

  /// Logger for persistence diagnostics including corrupt record detection.
  private let logger = Logger(subsystem: LogSubsystem.main, category: "Persistence")

  /// The time-to-live for cached news items.
  ///
  /// Defaults to 24 hours (86 400 seconds). Configurable via
  /// ``init(modelContainer:cacheTTL:)`` for testing or per-environment tuning.
  private let cacheTTL: TimeInterval

  /// The default TTL applied when no custom value is provided (24 hours).
  public static let defaultCacheTTL: TimeInterval = 86_400

  /// Maximum number of expired records to delete per batch during pruning.
  /// Prevents loading thousands of records into memory simultaneously.
  private static let pruneBatchSize = 100

  // MARK: - Init

  /// Creates a `PersistenceActor` backed by the given `ModelContainer`.
  ///
  /// A dedicated `ModelContext` is created from the container, owned
  /// exclusively by this actor for the lifetime of the object.
  ///
  /// - Parameters:
  ///   - modelContainer: The shared SwiftData container.
  ///   - cacheTTL: How long cached items remain valid before pruning.
  ///     Defaults to ``defaultCacheTTL`` (24 hours). Pass a shorter
  ///     duration in tests for faster TTL verification.
  public init(modelContainer: ModelContainer, cacheTTL: TimeInterval = PersistenceActor.defaultCacheTTL) {
    self.modelContext = ModelContext(modelContainer)
    self.cacheTTL = cacheTTL
    // Disable autosave — we save explicitly after mutations.
    modelContext.autosaveEnabled = false
  }

  // MARK: - Upsert

  /// Persists news items using an upsert strategy.
  ///
  /// - If an item with the same `id` already exists, its mutable fields
  ///   are updated in-place and `cachedAt` is refreshed.
  /// - If no matching record exists, a new `NewsItemPersistenceModel` is inserted.
  ///
  /// - Parameter items: The domain items to persist.
  /// - Throws: If the SwiftData save fails.
  public func save(_ items: [NewsItem]) async throws {
    guard !items.isEmpty else { return }

    // Fetch all existing records whose IDs match the incoming batch
    // in one query — avoids N individual fetches.
    // Note: errors are propagated (not swallowed) to prevent silent
    // duplicate insertion on schema corruption or migration failures.
    let incomingIDs = items.map(\.id)
    let existingDescriptor = FetchDescriptor<NewsItemPersistenceModel>(
      predicate: #Predicate { incomingIDs.contains($0.id) }
    )
    let existing = try modelContext.fetch(existingDescriptor)
    let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

    let now = Date()
    for item in items {
      if let record = existingByID[item.id] {
        // Update mutable fields — ID and schema remain stable.
        record.headline = item.headline
        record.summary = item.summary
        record.source = item.source
        record.articleURLString = item.articleURL?.absoluteString
        record.categoryRaw = item.category.rawValue
        record.latitude = item.coordinate.latitude
        record.longitude = item.coordinate.longitude
        record.publishedAt = item.publishedAt
        record.imageURLString = item.imageURL?.absoluteString
        record.cachedAt = now
        // Persist AI analysis results — only overwrite when new data is present.
        if let analysis = item.analysis {
          record.clickbaitScore = analysis.clickbaitScore
          record.sentimentRaw = analysis.sentiment.rawValue
          record.analysisConfidence = analysis.confidence
        }
      } else {
        let model = NewsItemPersistenceModel(from: item)
        modelContext.insert(model)
      }
    }

    try modelContext.save()
  }

  // MARK: - Fetch

  /// Fetches persisted news items, optionally filtered by region.
  ///
  /// When `region` is provided, results are constrained to items whose
  /// coordinates lie within a bounding box derived from the region's
  /// center and radius. This is an approximation — the clusterer performs
  /// exact spatial filtering downstream.
  ///
  /// - Parameters:
  ///   - region: Optional geographic filter (bounding box approximation).
  ///   - limit: Maximum number of items to return.
  ///   - offset: Number of items to skip (for pagination).
  /// - Returns: Domain `NewsItem` instances.
  public func fetch(in region: GeoRegion?, limit: Int?, offset: Int?) async throws -> [NewsItem] {
    var descriptor = FetchDescriptor<NewsItemPersistenceModel>(
      sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
    )

    if let region {
      // Approximate bounding box: 1° latitude ≈ 111 km.
      let latDelta = region.radiusMeters / 111_000
      // Guard against cos(90°) = 0 at polar latitudes — see URLSessionNewsService.
      let cosLat = max(cos(region.center.latitude * .pi / 180), 0.01)
      let lonDelta = region.radiusMeters / (111_000 * cosLat)
      let minLat = region.center.latitude - latDelta
      let maxLat = region.center.latitude + latDelta
      let minLon = region.center.longitude - lonDelta
      let maxLon = region.center.longitude + lonDelta

      descriptor.predicate = #Predicate<NewsItemPersistenceModel> {
        $0.latitude >= minLat && $0.latitude <= maxLat && $0.longitude >= minLon
          && $0.longitude <= maxLon
      }
    }

    if let limit { descriptor.fetchLimit = limit }
    if let offset, offset > 0 { descriptor.fetchOffset = offset }

    let models = try modelContext.fetch(descriptor)
    return models.compactMap { model in
      do {
        return try model.toDomainModel()
      } catch {
        logger.warning(
          """
          Corrupt persistence record skipped — id: \(model.id, privacy: .public), \
          error: \(error.localizedDescription, privacy: .public). \
          Record remains in store; consider manual cleanup.
          """
        )
        return nil
      }
    }

  }

  // MARK: - Delete

  /// Deletes a persisted news item by its unique identifier.
  ///
  /// - Parameter id: The ID of the item to remove.
  /// - Throws: If the SwiftData operation fails.
  public func delete(id: String) async throws {
    let descriptor = FetchDescriptor<NewsItemPersistenceModel>(
      predicate: #Predicate { $0.id == id }
    )
    let matches = try modelContext.fetch(descriptor)
    for match in matches { modelContext.delete(match) }
    if !matches.isEmpty { try modelContext.save() }
  }

  /// Deletes all persisted news items in a single batch operation.
  ///
  /// More efficient than calling ``delete(id:)`` in a loop — performs
  /// one fetch + one save instead of N individual round-trips.
  ///
  /// - Returns: The number of records deleted.
  /// - Throws: If the SwiftData operation fails.
  @discardableResult
  public func deleteAll() async throws -> Int {
    let descriptor = FetchDescriptor<NewsItemPersistenceModel>()
    let all = try modelContext.fetch(descriptor)
    guard !all.isEmpty else { return 0 }

    for record in all { modelContext.delete(record) }
    try modelContext.save()

    logger.info("Batch deleted \(all.count) news items.")
    return all.count
  }

  // MARK: - Prune

  /// Deletes all cached items whose `cachedAt` timestamp exceeds the TTL.
  ///
  /// Processes expired items in batches of ``pruneBatchSize`` with a
  /// `modelContext.save()` after **each batch** to ensure deleted records
  /// are committed before the next fetch. Without per-batch saves,
  /// SwiftData's in-memory dirty state could return already-deleted
  /// records in the next `fetch()`, creating an infinite loop.
  ///
  /// Intended to be called on app foreground or background refresh to keep
  /// storage bounded and data fresh.
  ///
  /// - Throws: If the SwiftData batch-delete or save fails.
  public func pruneExpired() async throws {
    let expiryDate = Date(timeIntervalSinceNow: -cacheTTL)
    var totalPruned = 0

    // Fetch and delete in batches to keep memory footprint bounded.
    // Each batch is saved immediately so the next fetch excludes
    // already-deleted records — preventing an infinite re-fetch loop.
    while true {
      var descriptor = FetchDescriptor<NewsItemPersistenceModel>(
        predicate: #Predicate { $0.cachedAt < expiryDate }
      )
      descriptor.fetchLimit = Self.pruneBatchSize

      let expired = try modelContext.fetch(descriptor)
      guard !expired.isEmpty else { break }

      for record in expired { modelContext.delete(record) }
      totalPruned += expired.count

      // Commit deletes before the next batch fetch so SwiftData
      // doesn't return the same records again.
      try modelContext.save()

      // If we got fewer than a full batch, we're done.
      if expired.count < Self.pruneBatchSize { break }
    }

    if totalPruned > 0 {
      logger.info("Pruned \(totalPruned) expired cache entries.")
    }
  }
}
