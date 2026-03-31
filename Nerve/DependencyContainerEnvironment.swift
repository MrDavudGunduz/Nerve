//
//  DependencyContainerEnvironment.swift
//  Nerve
//
//  Created by Davud Gunduz on 27.03.2026.
//

import Core
import OSLog
import SwiftUI

// MARK: - Environment Key

/// A SwiftUI `EnvironmentKey` that provides the app's ``DependencyContainer``
/// to any view in the hierarchy.
///
/// This eliminates the need for global static access (`Core.container`)
/// and enables **explicit dependency injection** through the view tree.
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
/// struct NewsMapView: View {
///   @Environment(\.dependencyContainer) var container
///
///   var body: some View { ... }
/// }
/// ```
private struct DependencyContainerKey: EnvironmentKey {
  static let defaultValue = DependencyContainer()
}

/// Tracks whether a container was explicitly injected via
/// `.environment(\.dependencyContainer, ...)`.
private struct DependencyContainerInjectedKey: EnvironmentKey {
  static let defaultValue = false
}

/// Logger for environment-related diagnostics.
private let environmentLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.davudgunduz.Nerve",
  category: "Environment"
)

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {

  /// The app-wide dependency container available to all SwiftUI views.
  ///
  /// - Important: Inject via `.environment(\.dependencyContainer, container)` at the
  ///   root of the view hierarchy. In `DEBUG` builds, accessing this property
  ///   without prior injection logs a warning to help catch configuration
  ///   mistakes early.
  var dependencyContainer: DependencyContainer {
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
