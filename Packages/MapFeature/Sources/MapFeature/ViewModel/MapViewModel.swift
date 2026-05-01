//
//  MapViewModel.swift
//  MapFeature
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import Foundation
import OSLog
import Observation

// MARK: - MapViewModel

/// Observable view model that drives ``NerveMapView`` with an offline-first
/// data pipeline.
///
/// ## Architecture
///
/// `MapViewModel` is split across multiple files by responsibility:
///
/// | File | Responsibility |
/// |------|----------------|
/// | `MapViewModel.swift` | State, dependencies, initializers |
/// | `MapViewModel+DataPipeline.swift` | loadNews, recluster, reset, location |
/// | `MapViewModel+CategoryFilter.swift` | Category toggle & clear |
/// | `MapViewModel+BackgroundTasks.swift` | Clustering, save, AI analysis, trim |
/// | `MapViewModelStubs.swift` | Preview / test stub services |
///
/// ## Data Flow
///
/// ```
/// 1. loadNews(for: region)
///    ├── [FAST PATH] fetch cached items → cluster → update UI immediately
///    └── [NETWORK]   fetch from NewsService concurrently
///                     ├── success → persist + merge → re-cluster → update UI
///                     └── failure → log warning, keep cached data displayed
/// ```
///
/// This pattern ensures the map is never blank: cached data is shown within
/// milliseconds while fresh data loads in the background.
///
/// ## Threading
///
/// - `@MainActor` isolation guarantees all `@Observable` state mutations are
///   dispatched on the main thread — no `@unchecked Sendable` suppression needed.
/// - Clustering runs on `AnnotationClusterer`'s actor (off main thread).
/// - Storage and network calls are awaited without blocking the main thread.
@MainActor
@Observable
public final class MapViewModel {

  // MARK: - Published State

  /// The current set of spatial clusters rendered on the map.
  public internal(set) var clusters: [NewsCluster] = []

  /// Whether a data load or clustering pass is in progress.
  public internal(set) var isLoading: Bool = false

  /// The last error encountered. Displayed as a dismissable banner.
  public internal(set) var error: NerveError?

  /// The user's current location (if available). Used to center the map.
  public internal(set) var userLocation: GeoCoordinate?

  /// The set of categories currently shown on the map.
  ///
  /// An empty set means **all categories** are visible.
  /// Use ``toggleCategory(_:in:zoomLevel:)`` to add/remove categories.
  public internal(set) var selectedCategories: Set<NewsCategory> = []

  // MARK: - Internal State

  /// Maximum number of items retained in memory.
  ///
  /// When exceeded, the oldest items (by `publishedAt`) are evicted.
  /// This prevents unbounded memory growth when the user pans the map
  /// across many regions during a single session.
  static let maxItemsCapacity = 500

  /// All items currently in memory (cached + fetched this session).
  ///
  /// Bounded to ``maxItemsCapacity`` — see ``trimOldestItems()``.
  var allItems: [NewsItem] = []

  /// Items after applying the active category filter.
  ///
  /// Returns `allItems` unchanged when `selectedCategories` is empty.
  var filteredItems: [NewsItem] {
    guard !selectedCategories.isEmpty else { return allItems }
    return allItems.filter { selectedCategories.contains($0.category) }
  }

  /// The last region successfully loaded for — used for deduplication.
  var lastRegion: GeoRegion?

  /// Tracked handle for the most-recently-initiated background save task.
  ///
  /// Storing the handle allows the previous save to be cancelled when a
  /// newer batch of items supersedes it, and prevents the task from being
  /// silently leaked when the view model is torn down.
  var saveTask: Task<Void, Never>?

  /// Tracked handle for the most-recently-initiated load task.
  ///
  /// When a new `loadNews` call arrives, the previous in-flight load is
  /// cancelled and replaced — eliminating the reentrancy race that the
  /// simple `isLoading` guard could not prevent.
  var loadTask: Task<Void, Never>?

  /// Tracked handle for the background AI analysis task.
  ///
  /// Cancelled on reset or when a new load supersedes the current analysis.
  var analyzeTask: Task<Void, Never>?

  let logger = Logger(subsystem: "com.davudgunduz.Nerve", category: "MapViewModel")

  // MARK: - Dependencies

  let clusterer: any ClusteringServiceProtocol
  let newsService: any NewsServiceProtocol
  let storageService: any StorageServiceProtocol
  let locationService: any LocationServiceProtocol
  let aiService: (any AIAnalysisServiceProtocol)?

  // MARK: - Init

  /// Creates a fully-wired view model for production use.
  public init(
    clusterer: any ClusteringServiceProtocol,
    newsService: any NewsServiceProtocol,
    storageService: any StorageServiceProtocol,
    locationService: any LocationServiceProtocol,
    aiService: (any AIAnalysisServiceProtocol)? = nil
  ) {
    self.clusterer = clusterer
    self.newsService = newsService
    self.storageService = storageService
    self.locationService = locationService
    self.aiService = aiService
  }

  /// Convenience init with explicit clusterer — used in tests and previews
  /// where the caller only needs to override clustering behavior.
  public init(clusterer: any ClusteringServiceProtocol = AnnotationClusterer()) {
    self.clusterer = clusterer
    self.newsService = StubNewsServiceInternal()
    self.storageService = StubStorageServiceInternal()
    self.locationService = StubLocationServiceInternal()
    self.aiService = nil
  }
}
