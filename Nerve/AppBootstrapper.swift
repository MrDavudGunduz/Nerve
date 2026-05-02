//
//  AppBootstrapper.swift
//  Nerve
//
//  Created by Davud Gunduz on 11.04.2026.
//

import AILayer
import ARFeature
import Core
import MapFeature
import NetworkLayer
import OSLog
import StorageLayer
import SwiftData

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

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.davudgunduz.Nerve",
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

    // Production REST client with exponential backoff retry.
    // Falls back to PlaceholderNewsService if no API endpoint is configured.
    #if DEBUG
      await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
        PlaceholderNewsService()
      }
    #else
      await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
        URLSessionNewsService(configuration: .production)
      }
    #endif

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
    await container.register(ARServiceProtocol.self, lifetime: .singleton) {
      ARService()
    }

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
  }
}

