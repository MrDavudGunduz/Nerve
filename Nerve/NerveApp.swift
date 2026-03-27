//
//  NerveApp.swift
//  Nerve
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core
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

  // MARK: - SwiftData Configuration

  /// Shared model container used across the entire application.
  ///
  /// Configured with persistent storage to enable offline-first functionality.
  /// All platform targets share the same schema and storage strategy.
  /// Model types are sourced from ``ModelRegistry/allModels`` to prevent
  /// forgotten registrations.
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
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  // MARK: - Scene

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.dependencyContainer, container)
    }
    .modelContainer(sharedModelContainer)
  }
}
