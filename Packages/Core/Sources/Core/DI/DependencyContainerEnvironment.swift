//
//  DependencyContainerEnvironment.swift
//  Core
//
//  Created by Davud Gunduz on 02.04.2026.
//

import OSLog
import SwiftUI

// MARK: - Environment Key

/// A SwiftUI `EnvironmentKey` that provides the app's ``DependencyContainer``
/// to any view in the hierarchy.
///
/// Defined in `Core` so that every feature package (e.g. `MapFeature`) can
/// read the container without depending on the app target.
///
/// ## SwiftUI Import Justification
///
/// This file is the **only** file in `Core` that imports SwiftUI, and it uses
/// **exclusively** `EnvironmentKey` and `EnvironmentValues` — no views, no
/// `@State`, no rendering types. This minimal surface allows all feature
/// packages to read the DI container via `@Environment` without a separate
/// bridge module. If `Core` ever needs a broader "no SwiftUI" policy, move
/// this file to a `CoreUI` micro-package.
///
/// ## Injecting the Container
///
/// In `NerveApp.swift`:
/// ```swift
/// ContentView()
///   .environment(\.dependencyContainer, container)
/// ```
///
/// ## Reading in Views
///
/// ```swift
/// struct NerveMapView: UIViewRepresentable {
///   @Environment(\.dependencyContainer) var container
/// }
/// ```
private struct DependencyContainerKey: EnvironmentKey {
  public static let defaultValue = DependencyContainer()
}

/// Tracks whether a container was explicitly injected via
/// `.environment(\.dependencyContainer, ...)`.
private struct DependencyContainerInjectedKey: EnvironmentKey {
  public static let defaultValue = false
}

/// Logger for environment-related diagnostics.
private let environmentLogger = Logger(
  subsystem: "com.davudgunduz.Nerve",
  category: "Environment"
)

/// Process-level flag set after the first successful injection.
///
/// During normal SwiftUI startup, `EnvironmentValues` getters are
/// called *before* `.environment()` modifiers run. Logging a warning
/// at that stage produces false-positive noise. This flag suppresses
/// the warning until at least one injection has occurred — after which
/// an uninjected access is genuinely unexpected.
private nonisolated(unsafe) var hasEverBeenInjected = false

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {

  /// The app-wide dependency container available to all SwiftUI views.
  ///
  /// - Important: Inject via `.environment(\.dependencyContainer, container)` at the
  ///   root of the view hierarchy. Accessing this property without prior injection
  ///   logs a warning. SwiftUI may read `EnvironmentValues` during view init
  ///   *before* the `.environment()` modifier runs — this is expected lifecycle
  ///   behavior, not a configuration error, so we log instead of crashing.
  public var dependencyContainer: DependencyContainer {
    get {
      // Only warn after at least one injection has occurred in this process.
      // Before that, SwiftUI is still assembling the view hierarchy —
      // reading the default value is expected lifecycle behavior.
      if hasEverBeenInjected && !self[DependencyContainerInjectedKey.self] {
        environmentLogger.warning(
          """
          DependencyContainer accessed but not yet injected. \
          Ensure .environment(\\.dependencyContainer, container) \
          is set on the root view hierarchy. \
          Services resolved from this container will fail with 'notRegistered' errors.
          """
        )
      }
      return self[DependencyContainerKey.self]
    }
    set {
      self[DependencyContainerKey.self] = newValue
      self[DependencyContainerInjectedKey.self] = true
      hasEverBeenInjected = true
    }
  }
}
