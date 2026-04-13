//
//  CoreLocationService.swift
//  MapFeature
//
//  Created by Davud Gunduz on 11.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import CoreLocation
  import Foundation
  import OSLog

  // MARK: - CoreLocationService

  /// Concrete `LocationServiceProtocol` implementation backed by `CoreLocation`.
  ///
  /// ## Swift 6 Concurrency
  ///
  /// `CLLocationManager` must be created, started, and stopped on the main
  /// thread (or a single thread-confined context). This is solved by:
  ///
  /// 1. Declaring `CoreLocationService` as `@MainActor` so all public API
  ///    calls are automatically dispatched to the main actor.
  /// 2. Using a non-isolated `LocationDelegate` bridge that captures results
  ///    into a `CheckedContinuation` and `AsyncStream`, safely crossing the
  ///    actor boundary via `@MainActor` closures.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let service = CoreLocationService()
  /// try await service.startTracking()
  ///
  /// // One-shot:
  /// let coord = try await service.requestCurrentLocation()
  ///
  /// // Continuous stream:
  /// for await location in service.locationStream {
  ///     mapViewModel.updateUserLocation(location)
  /// }
  /// ```
  @MainActor
  public final class CoreLocationService: LocationServiceProtocol {

    // MARK: - Properties

    private let manager: CLLocationManager
    private let delegate: LocationDelegate
    private let logger = Logger(subsystem: "com.davudgunduz.Nerve", category: "Location")

    /// The most recently received location fix, if any.
    public private(set) var lastKnownLocation: GeoCoordinate?

    /// A continuous `AsyncStream` of location updates.
    ///
    /// New values are emitted whenever `CLLocationManager` reports an update.
    /// Subscribe once and keep it alive for the lifetime of the map screen.
    public let locationStream: AsyncStream<GeoCoordinate>
    private let locationContinuation: AsyncStream<GeoCoordinate>.Continuation

    // MARK: - Init

    /// Creates the location service and configures the underlying `CLLocationManager`.
    ///
    /// Must be called on the main actor (guaranteed by `@MainActor` on the type).
    public init() {
      let (stream, continuation) = AsyncStream<GeoCoordinate>.makeStream()
      locationStream = stream
      locationContinuation = continuation

      delegate = LocationDelegate()
      manager = CLLocationManager()
      manager.delegate = delegate
      manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
      manager.distanceFilter = 500  // Emit updates every ~500 m

      // Forward delegate callbacks into this service via the delegate bridge.
      delegate.onLocationUpdate = { coord in
        continuation.yield(coord)
      }
    }

    // MARK: - LocationServiceProtocol

    /// Returns the most recently observed location without starting tracking.
    ///
    /// - Returns: The last fix, or `nil` if no fix has been acquired yet.
    /// - Throws: ``NerveError/location(message:context:)`` if permission is denied.
    public func currentLocation() async throws -> GeoCoordinate? {
      try checkAuthorization()
      return lastKnownLocation
    }

    /// Begins continuous location tracking.
    ///
    /// On first call, this presents the system location permission prompt.
    ///
    /// - Throws: ``NerveError/location(message:context:)`` if denied.
    public func startTracking() async throws {
      switch manager.authorizationStatus {
      case .notDetermined:
        manager.requestWhenInUseAuthorization()
      case .denied, .restricted:
        throw NerveError.location(message: "Location permission denied by the user.")
      default:
        break
      }
      logger.info("Starting continuous location tracking.")
      manager.startUpdatingLocation()
    }

    /// Stops continuous location tracking and releases the GPS hardware.
    public func stopTracking() async {
      logger.info("Stopping location tracking.")
      manager.stopUpdatingLocation()
    }

    /// Requests a single one-shot location fix.
    ///
    /// Uses `CLLocationManager.requestLocation()` which calls the delegate
    /// exactly once (best fix in ~10s) without starting continuous updates.
    ///
    /// - Returns: The user's current ``GeoCoordinate``.
    /// - Throws: ``NerveError/location(message:context:)`` on failure.
    public func requestCurrentLocation() async throws -> GeoCoordinate {
      try checkAuthorization()

      return try await withCheckedThrowingContinuation { continuation in
        self.delegate.oneShotContinuation = continuation
        self.manager.requestLocation()
      }
    }

    // MARK: - Helpers

    private func checkAuthorization() throws {
      let status = manager.authorizationStatus
      guard status == .authorizedWhenInUse || status == .authorizedAlways else {
        if status == .denied || status == .restricted {
          throw NerveError.location(message: "Location permission denied.")
        }
        return  // .notDetermined — will prompt on next action.
      }
    }
  }

  // MARK: - LocationDelegate

  /// A non-isolated `CLLocationManagerDelegate` bridge that forwards callbacks
  /// into Swift Concurrency contexts without violating actor isolation.
  ///
  /// `LocationDelegate` is a reference type intentionally left without actor
  /// isolation so the `CLLocationManager` (which calls delegates on the main
  /// thread) can invoke it freely. All forwarded callbacks target `@MainActor`
  /// closures set by `CoreLocationService`.
  private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    var onLocationUpdate: ((GeoCoordinate) -> Void)?
    var oneShotContinuation: CheckedContinuation<GeoCoordinate, Error>?

    func locationManager(
      _ manager: CLLocationManager,
      didUpdateLocations locations: [CLLocation]
    ) {
      guard let location = locations.last else { return }
      let coord = location.coordinate

      guard let geoCoord = GeoCoordinate(latitude: coord.latitude, longitude: coord.longitude)
      else { return }

      // Satisfy one-shot request if pending.
      if let continuation = oneShotContinuation {
        oneShotContinuation = nil
        continuation.resume(returning: geoCoord)
        return
      }

      // Feed continuous stream.
      onLocationUpdate?(geoCoord)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
      if let continuation = oneShotContinuation {
        oneShotContinuation = nil
        continuation.resume(
          throwing: NerveError.location(
            message: "CLLocationManager failed: \(error.localizedDescription)",
            context: ErrorContext(underlyingError: error)
          )
        )
      }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      let status = manager.authorizationStatus
      if status == .authorizedWhenInUse || status == .authorizedAlways {
        manager.startUpdatingLocation()
      }
    }
  }

#endif
