//
//  Constants.swift
//  Core
//
//  Created by Davud Gunduz on 19.05.2026.
//

import Foundation

// MARK: - LogSubsystem

/// Centralized logging subsystem identifiers for the Nerve application.
///
/// All `Logger` instances across the codebase should use these constants
/// instead of hardcoded strings. This eliminates typo-induced subsystem
/// fragmentation in Instruments and Console.app, and provides a single
/// place to update the bundle identifier if it ever changes.
///
/// ## Usage
///
/// ```swift
/// import OSLog
///
/// private static let logger = Logger(
///   subsystem: LogSubsystem.main,
///   category: "MyFeature"
/// )
/// ```
///
/// ## Subsystem Hierarchy
///
/// | Subsystem | Used By |
/// |-----------|---------|
/// | ``main`` | App target, Core, StorageLayer, AILayer |
/// | ``networkLayer`` | NetworkLayer services |
/// | ``mapFeature`` | MapFeature views and view models |
/// | ``arFeature`` | ARFeature views and sessions |
public enum LogSubsystem: Sendable {

  /// The primary subsystem for the Nerve application.
  ///
  /// Matches `CFBundleIdentifier` in the app target's `Info.plist`.
  /// Used by `NerveApp`, `AppBootstrapper`, `DependencyContainerEnvironment`,
  /// `PersistenceActor`, `RetryPolicy`, and `SettingsView`.
  public static let main = "com.davudgunduz.Nerve"

  /// Subsystem for the NetworkLayer package.
  ///
  /// Used by `URLSessionNewsService` and `URLSessionImageService`.
  public static let networkLayer = "com.davudgunduz.Nerve.NetworkLayer"

  /// Subsystem for the MapFeature package.
  ///
  /// Used by `MapViewModel` and related map UI components.
  public static let mapFeature = "com.davudgunduz.Nerve.MapFeature"

  /// Subsystem for the ARFeature package.
  ///
  /// Used by AR session coordinators and spatial views.
  public static let arFeature = "com.davudgunduz.Nerve.ARFeature"
}
