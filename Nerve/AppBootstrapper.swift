//
//  AppBootstrapper.swift
//  Nerve
//
//  Created by Davud Gunduz on 11.04.2026.
//

import AILayer
import BackgroundTasks
import Core
import MapFeature
import NetworkLayer
import OSLog
import StorageLayer
import SwiftData

#if canImport(ARFeature)
  import ARFeature
#endif

// MARK: - AppBootstrapper

/// Registers all services into the application's ``DependencyContainer``
/// during app startup.
///
/// Call ``bootstrap(container:)`` once from `NerveApp.body` via `.task {}`.
///
/// ## Lifecycle
///
/// Concrete implementations (network clients, SwiftData actors, CoreML models)
/// replace the placeholder registrations below as each module matures.
/// Placeholder services live in their respective module packages (e.g.,
/// ``NetworkLayer/PlaceholderNewsService``) to keep the app functional
/// and the DI container populated so that `resolve()` never throws
/// `notRegistered` at runtime.
///
/// ## Adding a New Service
///
/// 1. Create a concrete implementation conforming to the matching protocol.
/// 2. Replace the stub registration below with the real implementation.
///
/// ```swift
/// await container.register(NewsServiceProtocol.self) {
///     NewsAPIClient(baseURL: AppConfig.apiBaseURL)
/// }
/// ```
enum AppBootstrapper {

  // MARK: - Constants

  /// Background task identifier for periodic news refresh.
  ///
  /// Must match the identifier in `Info.plist` under
  /// `BGTaskSchedulerPermittedIdentifiers`.
  static let backgroundRefreshIdentifier = "com.davudgunduz.Nerve.newsRefresh"

  /// Uses a hardcoded subsystem string instead of `Bundle.main.bundleIdentifier`
  /// because static `let` initializers run before `@main` is fully constructed.
  private static let logger = Logger(
    subsystem: LogSubsystem.main,
    category: "AppBootstrapper"
  )

  /// Registers all application services into the given container.
  ///
  /// - Parameters:
  ///   - container: The app-wide ``DependencyContainer`` to populate.
  ///   - modelContainer: The SwiftData `ModelContainer` used by ``PersistenceActor``.
  static func bootstrap(container: DependencyContainer, modelContainer: ModelContainer) async {
    logger.info("Bootstrapping dependency container…")

    // MARK: - Clustering

    // AnnotationClusterer is the production implementation — not a stub.
    await container.register(ClusteringServiceProtocol.self, lifetime: .singleton) {
      AnnotationClusterer()
    }

    // MARK: - News (URLSession)

    // Production REST client with exponential backoff retry — used in ALL builds.
    // DEBUG builds previously used PlaceholderNewsService, preventing integration
    // testing with the real API. The production service is now registered
    // unconditionally; the view model already falls back to SeedData when the
    // API returns no results in DEBUG builds.
    #if DEBUG
      let newsConfig = NetworkConfiguration.development
    #else
      let newsConfig = NetworkConfiguration.production
    #endif
    await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
      URLSessionNewsService(configuration: newsConfig)
    }

    // Keep PlaceholderNewsService available as a named registration for unit tests
    // and SwiftUI previews that need deterministic, offline-safe data.
    await container.register(NewsServiceProtocol.self, name: "placeholder", lifetime: .singleton) {
      PlaceholderNewsService()
    }

    // MARK: - Storage (SwiftData)

    // Production: serializes all ModelContext access through PersistenceActor.
    let persistenceActor = PersistenceActor(modelContainer: modelContainer)
    await container.register(StorageServiceProtocol.self, lifetime: .singleton) {
      SwiftDataStorageService(persistenceActor: persistenceActor)
    }

    // MARK: - AI Analysis (On-Device NLP)

    // Production: actor-isolated NLTagger sentiment + heuristic clickbait detection.
    await container.register(AIAnalysisServiceProtocol.self, lifetime: .singleton) {
      HeadlineAnalyzer()
    }

    // MARK: - AR / Spatial Computing

    // Production: actor-isolated AR capability detection and USDZ asset management.
    // Only registered on platforms where ARFeature (RealityKit/ARKit) is available.
    #if canImport(ARFeature)
      await container.register(ARServiceProtocol.self, lifetime: .singleton) {
        ARService()
      }
    #endif

    // MARK: - Location (CoreLocation)

    // Production: platform-aware factory vends CoreLocationService on iOS/visionOS,
    // NullLocationService on macOS. Concrete type stays encapsulated in MapFeature.
    await container.register(LocationServiceProtocol.self, lifetime: .singleton) {
      await LocationServiceFactory.makeService()
    }

    // MARK: - Image Loading (URLSession + L1/L2 Cache)

    // Production: two-tier (memory + disk) image cache with request coalescing.
    await container.register(ImageServiceProtocol.self, lifetime: .singleton) {
      URLSessionImageService(cacheSizeMB: 100)
    }

    let count = await container.registrationCount
    logger.info("Bootstrap complete: \(count, privacy: .public) services registered.")

    // Register background tasks after all services are available.
    registerBackgroundTasks(container: container)
  }

  // MARK: - Background App Refresh

  /// Registers a `BGAppRefreshTask` for periodic news prefetching and cache pruning.
  ///
  /// The task identifier must be listed in `Info.plist` under
  /// `BGTaskSchedulerPermittedIdentifiers` for the system to accept the registration.
  ///
  /// ## Scheduling
  ///
  /// After registration, call ``scheduleBackgroundRefresh()`` to request the
  /// first execution. The task re-schedules itself on completion.
  ///
  /// ## Task Lifecycle
  ///
  /// 1. System wakes the app in the background.
  /// 2. Resolve `StorageServiceProtocol` and prune expired cache.
  /// 3. Optionally prefetch headlines for the user's last-known region.
  /// 4. Re-schedule the next refresh.
  private static func registerBackgroundTasks(container: DependencyContainer) {
    #if os(iOS)
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: backgroundRefreshIdentifier,
        using: nil
      ) { task in
        guard let refreshTask = task as? BGAppRefreshTask else { return }
        handleBackgroundRefresh(refreshTask, container: container)
      }
      logger.info("Background refresh task registered: \(backgroundRefreshIdentifier)")
    #endif
  }

  /// Schedules the next background app refresh request.
  ///
  /// Call this on:
  /// - App launch (after bootstrap)
  /// - After each successful background task completion
  /// - After the app enters the background (`scenePhase == .background`)
  static func scheduleBackgroundRefresh() {
    #if os(iOS)
      let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
      // Request earliest execution 30 minutes from now.
      request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
      do {
        try BGTaskScheduler.shared.submit(request)
        logger.debug("Background refresh scheduled.")
      } catch {
        logger.warning(
          "Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)"
        )
      }
    #endif
  }

  /// Handles a background refresh task by pruning expired cache entries.
  ///
  /// Uses `Task` with a deadline to ensure the system's time budget is respected.
  /// Re-schedules the next refresh on completion.
  #if os(iOS)
    private static func handleBackgroundRefresh(
      _ task: BGAppRefreshTask,
      container: DependencyContainer
    ) {
      let backgroundWork = Task {
        do {
          let storageService = try await container.resolve(StorageServiceProtocol.self)
          try await storageService.pruneExpiredCache()
          logger.info("Background refresh: expired cache pruned.")
          task.setTaskCompleted(success: true)
        } catch {
          logger.warning(
            "Background refresh failed: \(error.localizedDescription, privacy: .public)"
          )
          task.setTaskCompleted(success: false)
        }
        // Re-schedule for next interval.
        scheduleBackgroundRefresh()
      }

      // If the system revokes our background time, cancel the task.
      task.expirationHandler = {
        backgroundWork.cancel()
        task.setTaskCompleted(success: false)
      }
    }
  #endif
}

