//
//  MapViewModel+BackgroundTasks.swift
//  MapFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation

// MARK: - MapViewModel + Background Tasks

/// Extension containing background task orchestration: clustering, persistence,
/// AI analysis, and memory management.
///
/// ## Task Lifecycle
///
/// Each background operation is tracked via a `Task<Void, Never>?` handle.
/// When a newer operation supersedes an in-flight one, the previous task is
/// cancelled before the new one launches — preventing stale writes and
/// resource contention.
///
/// | Task | Priority | Purpose |
/// |------|----------|---------|
/// | `saveTask` | `.background` | Persist merged items to SwiftData |
/// | `analyzeTask` | `.userInitiated` | On-device AI headline analysis |
extension MapViewModel {

  // MARK: - Clustering

  /// Runs the clustering engine and updates the published `clusters` state.
  ///
  /// Clustering runs on `AnnotationClusterer`'s actor executor, off the main
  /// thread. The result is assigned back on `@MainActor` through this method.
  func updateClusters(
    with items: [NewsItem],
    in region: GeoRegion,
    zoomLevel: Double
  ) async {
    do {
      let result = try await clusterer.cluster(items: items, in: region, zoomLevel: zoomLevel)
      clusters = result
      logger.debug("Clustered \(items.count) items → \(result.count) clusters")
    } catch {
      logger.error("Clustering failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Persistence

  /// Schedules a background save, cancelling any previous in-flight save.
  ///
  /// Using a non-detached `Task` keeps the work within the `@MainActor`
  /// context (for priority propagation) while suspending away from the
  /// main thread during the `await storageService.saveNews` call.
  /// The `saveTask` handle lets us cancel stale saves on `reset()`.
  ///
  /// - Parameter items: The items to persist.
  func scheduleSave(_ items: [NewsItem]) {
    saveTask?.cancel()
    saveTask = Task(priority: .background) { [weak self] in
      guard let self, !Task.isCancelled else { return }
      do {
        try await storageService.saveNews(items)
        logger.debug("Persisted \(items.count) items to storage.")
      } catch {
        logger.warning("Background save failed: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - AI Analysis

  /// Schedules background AI analysis for items that lack an `analysis` result.
  ///
  /// After analysis completes, the enriched items are merged back into `allItems`,
  /// persisted, and re-clustered so credibility badges appear on the map.
  ///
  /// - Parameters:
  ///   - items: The full set of items to check for analysis.
  ///   - region: The current visible region (for re-clustering after analysis).
  ///   - zoomLevel: The current zoom level.
  func scheduleAnalysis(
    _ items: [NewsItem],
    in region: GeoRegion,
    zoomLevel: Double
  ) {
    guard let aiService else { return }

    let unanalyzed = items.filter { $0.analysis == nil }
    guard !unanalyzed.isEmpty else {
      logger.debug("All \(items.count) items already analyzed — skipping.")
      return
    }

    analyzeTask?.cancel()
    analyzeTask = Task(priority: .userInitiated) { @MainActor [weak self] in
      guard let self, !Task.isCancelled else { return }
      logger.info("Starting AI analysis for \(unanalyzed.count) items…")

      do {
        let headlines = unanalyzed.map(\.headline)
        let analyses = try await aiService.analyzeBatch(headlines)
        guard !Task.isCancelled else { return }

        // Enrich items with analysis results using the copy-on-write helper.
        // `withAnalysis(_:)` is resilient to future property additions on NewsItem.
        let enriched = zip(unanalyzed, analyses).map { item, analysis in
          item.withAnalysis(analysis)
        }

        // Merge enriched items back into allItems.
        var itemsByID = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })
        for item in enriched {
          itemsByID[item.id] = item
        }
        allItems = Array(itemsByID.values)
        trimOldestItems()

        // Re-cluster to refresh credibility badges.
        await updateClusters(with: filteredItems, in: region, zoomLevel: zoomLevel)

        // Persist enriched items.
        scheduleSave(Array(itemsByID.values))

        logger.info("AI analysis complete: \(enriched.count) items enriched.")
      } catch {
        if !Task.isCancelled {
          logger.warning("AI analysis failed: \(error.localizedDescription)")
        }
      }
    }
  }

  // MARK: - Memory Management

  /// Trims ``allItems`` to ``maxItemsCapacity`` by evicting the oldest items.
  ///
  /// Called after every mutation of `allItems` to prevent unbounded memory
  /// growth when the user pans across many regions during a single session.
  /// Items are sorted by `publishedAt` descending — the most recent items
  /// are retained.
  func trimOldestItems() {
    guard allItems.count > Self.maxItemsCapacity else { return }
    let sorted = allItems.sorted { $0.publishedAt > $1.publishedAt }
    let evictedCount = allItems.count - Self.maxItemsCapacity
    allItems = Array(sorted.prefix(Self.maxItemsCapacity))
    logger.debug(
      "Memory cap reached: evicted \(evictedCount) oldest items, retaining \(Self.maxItemsCapacity)."
    )
  }
}
