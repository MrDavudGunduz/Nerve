//
//  DependencyContainerEnvironment.swift
//  Nerve
//
//  Created by Davud Gunduz on 27.03.2026.
//

import Core
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

// MARK: - EnvironmentValues Extension

extension EnvironmentValues {

  /// The app-wide dependency container available to all SwiftUI views.
  ///
  /// - Note: Inject via `.environment(\.dependencyContainer, container)` at the
  ///   root of the view hierarchy. If not injected, a fresh empty container
  ///   is provided as the default.
  var dependencyContainer: DependencyContainer {
    get { self[DependencyContainerKey.self] }
    set { self[DependencyContainerKey.self] = newValue }
  }
}
