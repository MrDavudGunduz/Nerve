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

#if canImport(ARFeature)
  import ARFeature
#endif

/// The main entry point for the Nerve application.
///
/// Nerve is a multiplatform app (iOS · macOS · visionOS) that provides
/// spatial news intelligence with on-device AI analysis.
///
/// ## Scene Architecture
///
/// - **2D Window** (all platforms): ``ContentView`` with tab/sidebar navigation.
/// - **Volumetric Window** (visionOS): ``VolumetricNewsView`` for 3D news models.
/// - **Immersive Space** (visionOS): ``SpatialMapView`` for the spatial news map.
///
/// ## visionOS Scene Transitions
///
/// The ``SpatialTransitionManager`` orchestrates smooth transitions between
/// the three scene tiers:
///
/// ```
/// Standard 2D ←→ Volumetric 3D
/// Standard 2D ←→ Immersive Space
/// Volumetric 3D → (via Standard) → Immersive Space
/// ```
@main
struct NerveApp: App {

  // MARK: - Dependencies

  /// The application-wide dependency container.
  ///
  /// Injected into the SwiftUI view hierarchy via
  /// `.environment(\.dependencyContainer, ...)` so that any view
  /// can access services without global static coupling.
  private let container = DependencyContainer()

  /// Manages transitions between 2D, Volumetric, and Immersive scenes on visionOS.
  ///
  /// Shared across the 2D window and the spatial toolbar to ensure
  /// consistent state tracking and prevent overlapping transitions.
  #if os(visionOS)
    @State private var transitionManager = SpatialTransitionManager()
  #endif

  // MARK: - Logging

  /// Logger for app-level lifecycle events.
  ///
  /// Uses a hardcoded subsystem string instead of `Bundle.main.bundleIdentifier`
  /// because static `let` initializers run before the `@main` struct is fully
  /// constructed — `Bundle.main` may not be fully available at that point,
  /// risking a crash or incorrect subsystem resolution.
  private static let logger = Logger(
    subsystem: LogSubsystem.main,
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
  /// Uses ``NerveSchemaMigrationPlan`` to ensure safe schema evolution
  /// across app updates. Without a migration plan, any schema change
  /// would cause either a crash or silent database reset.
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
        migrationPlan: NerveSchemaMigrationPlan.self,
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
          migrationPlan: NerveSchemaMigrationPlan.self,
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

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    // Primary 2D window — all platforms.
    WindowGroup {
      ContentView()
        .environment(\.dependencyContainer, container)
        #if os(visionOS)
          .overlay(alignment: .bottom) {
            SpatialSceneToolbar(transitionManager: transitionManager)
          }
        #endif
        .task {
          await AppBootstrapper.bootstrap(
            container: container,
            modelContainer: sharedModelContainer
          )
          // Schedule the first background refresh after bootstrap completes.
          AppBootstrapper.scheduleBackgroundRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .background {
            AppBootstrapper.scheduleBackgroundRefresh()
          }
        }
    }
    .modelContainer(sharedModelContainer)

    // visionOS: Volumetric 3D news viewer.
    #if os(visionOS)
      WindowGroup(id: SpatialTransitionManager.volumetricWindowID) {
        VolumetricNewsView()
          .environment(\.dependencyContainer, container)
          .onDisappear {
            // Sync transition manager if user closes via system UI.
            if transitionManager.currentMode == .volumetric {
              transitionManager.resetToStandard()
            }
          }
      }
      .windowStyle(.volumetric)
      .defaultSize(
        width: 0.5,
        height: 0.5,
        depth: 0.5,
        in: .meters
      )

      // visionOS: Immersive spatial map experience.
      ImmersiveSpace(id: SpatialTransitionManager.immersiveSpaceID) {
        SpatialMapView()
          .onDisappear {
            // Sync transition manager if user closes via system UI.
            if transitionManager.currentMode == .immersive {
              transitionManager.resetToStandard()
            }
          }
      }
      .immersionStyle(selection: .constant(.mixed), in: .mixed)
    #endif
  }
}
