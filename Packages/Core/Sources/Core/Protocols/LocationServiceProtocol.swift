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

  /// The most recently observed location, or `nil` if unavailable.
  var currentLocation: GeoCoordinate? { get async }

  /// Begins continuous location tracking.
  ///
  /// - Throws: If location permissions are denied or services are unavailable.
  func startTracking() async throws

  /// Stops continuous location tracking and releases resources.
  func stopTracking() async

  /// Requests the user's location once without starting continuous tracking.
  ///
  /// - Returns: The user's current ``GeoCoordinate``.
  func requestCurrentLocation() async throws -> GeoCoordinate
}
