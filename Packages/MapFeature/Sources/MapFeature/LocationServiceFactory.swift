//
//  LocationServiceFactory.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

import Core
import CoreLocation
import OSLog

// MARK: - LocationServiceFactory

/// Factory that vends the platform-appropriate ``LocationServiceProtocol``
/// implementation without leaking concrete types into the app target.
///
/// ## Design Rationale
///
/// `CoreLocationService` lives behind a `#if os(iOS) || os(visionOS)` gate
/// because `CLLocationManager` continuous-tracking APIs are unavailable on
/// macOS Catalyst / macOS native targets. Exposing a factory method lets the
/// bootstrapper remain platform-agnostic while delegating the conditional
/// compilation to the module that owns the concrete implementation.
///
/// ## Usage
///
/// ```swift
/// await container.register(LocationServiceProtocol.self, lifetime: .singleton) {
///     await LocationServiceFactory.makeService()
/// }
/// ```
public enum LocationServiceFactory {

  /// Creates and returns the platform-appropriate location service.
  ///
  /// - Returns: A ``LocationServiceProtocol`` conforming instance:
  ///   - **iOS / visionOS**: ``CoreLocationService`` backed by `CLLocationManager`.
  ///   - **macOS**: ``NullLocationService`` that safely no-ops all calls.
  @MainActor
  public static func makeService() -> any LocationServiceProtocol {
    #if os(iOS) || os(visionOS)
      CoreLocationService()
    #else
      NullLocationService()
    #endif
  }
}

// MARK: - NullLocationService

/// A no-op ``LocationServiceProtocol`` for platforms where CoreLocation
/// continuous tracking is unavailable (e.g., macOS).
///
/// All methods return safe defaults and log a warning so developers are
/// aware the location subsystem is inactive on the current platform.
struct NullLocationService: LocationServiceProtocol, Sendable {

  private let logger = Logger(
    subsystem: "com.davudgunduz.Nerve",
    category: "NullLocationService"
  )

  func currentLocation() async throws -> GeoCoordinate? {
    logger.warning("NullLocationService.currentLocation() called — no location available on this platform.")
    return nil
  }

  func startTracking() async throws {
    logger.warning("NullLocationService.startTracking() called — location tracking unavailable on this platform.")
  }

  func stopTracking() async {
    // No-op.
  }

  func requestCurrentLocation() async throws -> GeoCoordinate {
    throw NerveError.location(
      message: "Location services are not available on this platform."
    )
  }
}
