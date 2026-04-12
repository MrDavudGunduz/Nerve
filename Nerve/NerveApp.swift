//
//  NerveApp.swift
//  Nerve
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core
import OSLog
import StorageLayer
import SwiftData
import SwiftUI

/// The main entry point for the Nerve application.
///
/// Nerve is a multiplatform app (iOS · macOS · visionOS) that provides
/// spatial news intelligence with on-device AI analysis.
@main
struct NerveApp: App {

  // MARK: - Dependencies

  /// The application-wide dependency container.
  ///
  /// Injected into the SwiftUI view hierarchy via
  /// `.environment(\.dependencyContainer, ...)` so that any view
  /// can access services without global static coupling.
  private let container = DependencyContainer()

  // MARK: - Logging

  /// Logger for app-level lifecycle events.
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.davudgunduz.Nerve",
    category: "AppLifecycle"
  )

  // MARK: - SwiftData Configuration

  /// Shared model container used across the entire application.
  ///
  /// Configured with persistent storage to enable offline-first functionality.
  /// All platform targets share the same schema and storage strategy.
  /// Model types are sourced from ``ModelRegistry/allModels`` to prevent
  /// forgotten registrations.
  ///
  /// If persistent storage creation fails (e.g., migration issues),
  /// falls back to an in-memory container and logs the error
  /// instead of crashing.
  var sharedModelContainer: ModelContainer = {
    let schema = Schema(ModelRegistry.allModels)
    let modelConfiguration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false
    )

    do {
      return try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )
    } catch {
      logger.error(
        """
        Failed to create persistent ModelContainer: \(error.localizedDescription, privacy: .public). \
        Falling back to in-memory storage. User data will NOT persist across launches.
        """
      )

      // Fallback: in-memory container so the app remains functional
      let fallbackConfig = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
      )
      do {
        return try ModelContainer(
          for: schema,
          configurations: [fallbackConfig]
        )
      } catch {
        // If even in-memory fails, the schema itself is broken — unrecoverable.
        fatalError(
          "ModelContainer creation failed for both persistent and in-memory storage: \(error)"
        )
      }
    }
  }()

  // MARK: - Scene

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.dependencyContainer, container)
        .task {
          await AppBootstrapper.bootstrap(
            container: container,
            modelContainer: sharedModelContainer
          )
        }
    }
    .modelContainer(sharedModelContainer)
  }
}
