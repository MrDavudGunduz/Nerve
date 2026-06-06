//
//  FeatureFlags.swift
//  Core
//
//  Created by Davud Gunduz on 06.06.2026.
//

import Foundation

// MARK: - FeatureFlags

/// Centralized feature flag registry for the Nerve application.
///
/// Replaces scattered `#if DEBUG` conditionals with a single, queryable
/// registry. Each flag has a compile-time default that can be overridden
/// at runtime via `UserDefaults` (e.g., from a developer settings panel)
/// or — in the future — a server-driven configuration system
/// (Firebase Remote Config, LaunchDarkly, etc.).
///
/// ## Usage
///
/// ```swift
/// if FeatureFlags.seedDataEnabled {
///   // inject seed data for development
/// }
/// ```
///
/// ## Adding a New Flag
///
/// 1. Add a `static var` below with a `#if DEBUG` compile-time default.
/// 2. Add a matching `UserDefaults` key in ``Key`` if runtime override is needed.
/// 3. Update `allFlags` for diagnostics/logging.
///
/// ## Runtime Override
///
/// ```swift
/// FeatureFlags.setOverride(true, for: .seedData)
/// ```
///
/// Overrides persist across launches via `UserDefaults.standard`.
/// Call ``removeOverride(for:)`` to revert to the compile-time default.
public enum FeatureFlags: Sendable {

  // MARK: - Keys

  /// `UserDefaults` keys for runtime flag overrides.
  ///
  /// Keys are prefixed with `nerve.featureFlag.` to avoid collisions
  /// with other `UserDefaults` entries.
  public enum Key: String, CaseIterable, Sendable {
    case seedData = "nerve.featureFlag.seedData"
    case developerSettings = "nerve.featureFlag.developerSettings"
    case certificatePinning = "nerve.featureFlag.certificatePinning"
    case verboseLogging = "nerve.featureFlag.verboseLogging"
  }

  // MARK: - Flags

  /// Whether to inject seed data when the API returns empty results.
  ///
  /// - **DEBUG default:** `true` — enables offline development.
  /// - **RELEASE default:** `false` — never show demo data in production.
  public static var seedDataEnabled: Bool {
    override(for: .seedData) ?? Self.debugDefault(true)
  }

  /// Whether the developer diagnostics section is visible in Settings.
  ///
  /// - **DEBUG default:** `true` — shows Swift version, concurrency mode, etc.
  /// - **RELEASE default:** `false` — hidden from end users.
  public static var developerSettingsVisible: Bool {
    override(for: .developerSettings) ?? Self.debugDefault(true)
  }

  /// Whether SSL certificate pinning is enforced on network requests.
  ///
  /// - **DEBUG default:** `false` — allows Charles Proxy / mitmproxy inspection.
  /// - **RELEASE default:** `true` — enforces pinning against MITM attacks.
  public static var certificatePinningEnabled: Bool {
    override(for: .certificatePinning) ?? Self.releaseDefault(true)
  }

  /// Whether verbose logging is enabled across all subsystems.
  ///
  /// - **DEBUG default:** `true` — full diagnostic output.
  /// - **RELEASE default:** `false` — minimal logging for performance.
  public static var verboseLoggingEnabled: Bool {
    override(for: .verboseLogging) ?? Self.debugDefault(true)
  }

  // MARK: - Runtime Overrides

  /// Sets a runtime override for the given flag key.
  ///
  /// The override persists in `UserDefaults.standard` across launches.
  ///
  /// - Parameters:
  ///   - value: The override value.
  ///   - key: The flag key to override.
  public static func setOverride(_ value: Bool, for key: Key) {
    UserDefaults.standard.set(value, forKey: key.rawValue)
  }

  /// Removes the runtime override for the given flag key.
  ///
  /// After removal, the flag returns its compile-time default.
  ///
  /// - Parameter key: The flag key to reset.
  public static func removeOverride(for key: Key) {
    UserDefaults.standard.removeObject(forKey: key.rawValue)
  }

  /// Removes all runtime flag overrides.
  ///
  /// Primarily intended for test teardown.
  public static func removeAllOverrides() {
    for key in Key.allCases {
      UserDefaults.standard.removeObject(forKey: key.rawValue)
    }
  }

  // MARK: - Diagnostics

  /// Returns a snapshot of all flag values for logging or display.
  ///
  /// Useful in the developer settings panel or crash reports.
  ///
  /// ```swift
  /// for (name, value) in FeatureFlags.allFlags {
  ///   logger.info("\(name): \(value)")
  /// }
  /// ```
  public static var allFlags: [(name: String, value: Bool)] {
    [
      ("seedDataEnabled", seedDataEnabled),
      ("developerSettingsVisible", developerSettingsVisible),
      ("certificatePinningEnabled", certificatePinningEnabled),
      ("verboseLoggingEnabled", verboseLoggingEnabled),
    ]
  }

  // MARK: - Private

  /// Reads a runtime override from `UserDefaults`, if set.
  ///
  /// Returns `nil` if no override exists, allowing the compile-time
  /// default to take effect.
  private static func override(for key: Key) -> Bool? {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: key.rawValue) != nil else { return nil }
    return defaults.bool(forKey: key.rawValue)
  }

  /// Returns `value` in DEBUG builds, `false` otherwise.
  private static func debugDefault(_ value: Bool) -> Bool {
    #if DEBUG
      return value
    #else
      return false
    #endif
  }

  /// Returns `value` in RELEASE builds, `false` in DEBUG.
  private static func releaseDefault(_ value: Bool) -> Bool {
    #if DEBUG
      return false
    #else
      return value
    #endif
  }
}
