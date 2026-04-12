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

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {

  /// The app-wide dependency container available to all SwiftUI views.
  ///
  /// - Important: Inject via `.environment(\.dependencyContainer, container)` at the
  ///   root of the view hierarchy. In `DEBUG` builds, accessing this without prior
  ///   injection logs a warning to help catch configuration mistakes early.
  public var dependencyContainer: DependencyContainer {
    get {
      #if DEBUG
        if !self[DependencyContainerInjectedKey.self] {
          environmentLogger.warning(
            """
            DependencyContainer accessed but never injected. \
            Add .environment(\\.dependencyContainer, container) to the root view hierarchy.
            """
          )
        }
      #endif
      return self[DependencyContainerKey.self]
    }
    set {
      self[DependencyContainerKey.self] = newValue
      self[DependencyContainerInjectedKey.self] = true
    }
  }
}
