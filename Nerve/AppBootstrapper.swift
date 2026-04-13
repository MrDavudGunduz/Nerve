//
//  AppBootstrapper.swift
//  Nerve
//
//  Created by Davud Gunduz on 11.04.2026.
//

import Core
import MapFeature
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
/// replace the stub registrations below as each module matures. Stubs are used
/// in the interim to keep the app functional and the DI container populated so
/// that `resolve()` never throws `notRegistered` at runtime.
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
  @MainActor
  static func bootstrap(container: DependencyContainer, modelContainer: ModelContainer) async {
    logger.info("Bootstrapping dependency container…")

    // MARK: - Clustering

    // AnnotationClusterer is the production implementation — not a stub.
    await container.register(ClusteringServiceProtocol.self, lifetime: .singleton) {
      AnnotationClusterer()
    }

    // MARK: - News (Stub)

    // TODO: Replace with NetworkNewsService once NetworkLayer is implemented.
    await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
      StubNewsService()
    }

    // MARK: - Storage (SwiftData)

    // Production: serializes all ModelContext access through PersistenceActor.
    let persistenceActor = PersistenceActor(modelContainer: modelContainer)
    await container.register(StorageServiceProtocol.self, lifetime: .singleton) {
      SwiftDataStorageService(persistenceActor: persistenceActor)
    }

    // MARK: - AI Analysis (Stub)

    // TODO: Replace with CoreMLAnalysisService once AILayer model is added.
    await container.register(AIAnalysisServiceProtocol.self, lifetime: .singleton) {
      StubAIAnalysisService()
    }

    // MARK: - Location (CoreLocation)

    // Production: @MainActor-isolated CLLocationManager bridge.
    await container.register(LocationServiceProtocol.self, lifetime: .singleton) {
      await CoreLocationService()
    }

    let count = await container.registrationCount
    logger.info("Bootstrap complete: \(count, privacy: .public) services registered.")
  }
}

// MARK: - Stub Implementations

// These stubs satisfy protocol contracts and keep the app runnable while
// concrete implementations are being developed. Each stub logs a warning
// so developers are aware when a real service is needed.

// MARK: StubNewsService

private struct StubNewsService: NewsServiceProtocol {

  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] {
    Logger(subsystem: "Nerve", category: "Stub").warning(
      "StubNewsService.fetchNews called — no data returned. Implement NetworkNewsService."
    )
    return []
  }

  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(
      message:
        "StubNewsService does not support fetchNewsDetail(id:). Implement NetworkNewsService."
    )
  }
}

// MARK: StubAIAnalysisService

private struct StubAIAnalysisService: AIAnalysisServiceProtocol {

  func analyzeHeadline(_ headline: String) async throws -> HeadlineAnalysis {
    HeadlineAnalysis(clickbaitScore: 0.0, sentiment: .neutral, confidence: 0.0)
  }

  func analyzeBatch(_ headlines: [String]) async throws -> [HeadlineAnalysis] {
    headlines.map { _ in
      HeadlineAnalysis(clickbaitScore: 0.0, sentiment: .neutral, confidence: 0.0)
    }
  }
}
