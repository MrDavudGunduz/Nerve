//
//  LocationServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for accessing the user's geographic location.
///
/// Concrete implementations use `CoreLocation` in the feature modules.
/// `Core` defines only the contract to remain platform-agnostic.
public protocol LocationServiceProtocol: Sendable {

  /// Returns the most recently observed location, or `nil` if no fix is available yet.
  ///
  /// Unlike a `get async` property, this function can propagate errors — for example,
  /// distinguishing "no GPS fix yet" (`nil` return) from "location permission denied"
  /// (thrown `NerveError.location`).
  ///
  /// - Returns: The last known ``GeoCoordinate``, or `nil` if no fix has been acquired.
  /// - Throws: ``NerveError/location(message:context:)`` if location services are
  ///   unavailable or permission is denied.
  func currentLocation() async throws -> GeoCoordinate?

  /// Begins continuous location tracking.
  ///
  /// Presents the system permission prompt on first call if
  /// authorization status is `.notDetermined`.
  ///
  /// - Throws: ``NerveError/location(message:context:)`` if location
  ///   permissions are denied or services are unavailable.
  func startTracking() async throws

  /// Stops continuous location tracking and releases resources.
  func stopTracking() async

  /// Requests the user's location once without starting continuous tracking.
  ///
  /// Uses `CLLocationManager.requestLocation()` internally — provides
  /// a single best-available fix in approximately 10 seconds.
  ///
  /// - Returns: The user's current ``GeoCoordinate``.
  /// - Throws: ``NerveError/location(message:context:)`` if the fix fails
  ///   or permission is denied.
  func requestCurrentLocation() async throws -> GeoCoordinate
}
