//
//  MapStateUpdater.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import CoreLocation
  import MapKit
  import UIKit

  // MARK: - MapStateUpdater

  /// Pure-function state updater that synchronises `MKMapView` overlays and
  /// annotations with the current ``MapViewModel`` snapshot.
  ///
  /// ## Design Rationale
  ///
  /// `NerveMapView.updateUIView` previously held ~90 lines covering six
  /// independent concerns. By extracting each concern into a static method,
  /// the call-site becomes a clear, declarative pipeline and each update
  /// step can be unit-tested in isolation.
  ///
  /// All methods are `static` and side-effect-free in the sense that they
  /// only mutate the `MKMapView` and `Coordinator` state they are given —
  /// no retained state, no closures, no reference cycles.
  @MainActor
  enum MapStateUpdater {

    // MARK: - Annotation Diffing

    /// Performs O(n) annotation diffing — removes stale annotations (with
    /// animated collapse for clusters), adds new ones, and leaves unchanged
    /// annotations untouched.
    ///
    /// - Parameters:
    ///   - mapView: The map to synchronise annotations on.
    ///   - clusters: The latest cluster set from the view model.
    static func diffAnnotations(on mapView: MKMapView, clusters: [NewsCluster]) {
      let nextByID = Dictionary(uniqueKeysWithValues: clusters.map { ($0.id, $0) })
      let existing = mapView.annotations.compactMap { $0 as? NewsAnnotation }
      let existingIDs = Set(existing.map { $0.cluster.id })
      let nextIDs = Set(nextByID.keys)

      // ── Animated Removal ──
      let toRemove = existing.filter { !nextIDs.contains($0.cluster.id) }
      if !toRemove.isEmpty {
        var unanimated: [MKAnnotation] = []

        for annotation in toRemove {
          if annotation.cluster.isCluster,
            let view = mapView.view(for: annotation) as? ClusterAnnotationView
          {
            view.animateDisappearance {
              mapView.removeAnnotation(annotation)
            }
          } else {
            unanimated.append(annotation)
          }
        }

        if !unanimated.isEmpty {
          mapView.removeAnnotations(unanimated)
        }
      }

      // ── Addition ──
      let newIDs = nextIDs.subtracting(existingIDs)
      let toAdd = newIDs.compactMap { nextByID[$0].map { NewsAnnotation(cluster: $0) } }
      if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
    }

    // MARK: - Skeleton Loading State

    /// Toggles skeleton shimmer on all visible annotation views based on the
    /// view model's loading state.
    ///
    /// - Parameters:
    ///   - mapView: The map whose annotation views are updated.
    ///   - isLoading: Whether a data load is in progress.
    static func updateSkeletonState(on mapView: MKMapView, isLoading: Bool) {
      let allViews = mapView.annotations.compactMap { mapView.view(for: $0) }
      if isLoading {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.showSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.showSkeleton() }
      } else {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.hideSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.hideSkeleton() }
      }
    }

    // MARK: - Adaptive Map Style

    /// Updates the map's preferred configuration when the interface style
    /// (light / dark) changes, avoiding redundant configuration swaps.
    ///
    /// - Parameters:
    ///   - mapView: The map to reconfigure.
    ///   - coordinator: The coordinator tracking the last known interface style.
    static func updateMapStyle(on mapView: MKMapView, coordinator: NerveMapView.Coordinator) {
      let currentStyle = mapView.traitCollection.userInterfaceStyle
      guard currentStyle != coordinator.lastInterfaceStyle else { return }
      coordinator.lastInterfaceStyle = currentStyle
      let mapConfig =
        currentStyle == .dark
        ? MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        : MKStandardMapConfiguration()
      mapConfig.pointOfInterestFilter = .excludingAll
      mapView.preferredConfiguration = mapConfig
    }

    // MARK: - User Location Pulse Ring

    /// Updates the translucent pulse ring overlay around the user's current
    /// location, avoiding redundant remove/add churn when the location hasn't
    /// changed.
    ///
    /// - Parameters:
    ///   - mapView: The map to update overlays on.
    ///   - coordinator: The coordinator tracking the last known user location.
    ///   - userLocation: The current user coordinate, or `nil` if unavailable.
    static func updateUserLocationOverlay(
      on mapView: MKMapView,
      coordinator: NerveMapView.Coordinator,
      userLocation: GeoCoordinate?
    ) {
      guard let coord = userLocation, coord != coordinator.lastUserLocation else { return }
      coordinator.lastUserLocation = coord
      let clCoord = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
      let existingCircles = mapView.overlays.compactMap { $0 as? MKCircle }
      if !existingCircles.isEmpty {
        mapView.removeOverlays(existingCircles)
      }
      mapView.addOverlay(MKCircle(center: clCoord, radius: 150), level: .aboveRoads)
    }

    // MARK: - Loading Indicator

    /// Starts or stops the `UIActivityIndicatorView` based on the loading state.
    ///
    /// - Parameters:
    ///   - mapView: The map containing the loading indicator (identified by ``ViewTag``).
    ///   - isLoading: Whether a data load is in progress.
    static func updateLoadingIndicator(on mapView: MKMapView, isLoading: Bool) {
      guard
        let indicator = mapView.viewWithTag(ViewTag.loadingIndicator) as? UIActivityIndicatorView
      else { return }
      isLoading ? indicator.startAnimating() : indicator.stopAnimating()
    }

    // MARK: - Error Banner

    /// Shows the error banner if an error is present.
    ///
    /// - Parameters:
    ///   - mapView: The map containing the error banner (identified by ``ViewTag``).
    ///   - error: The current error, or `nil` if none.
    static func updateErrorBanner(on mapView: MKMapView, error: NerveError?) {
      guard
        let banner = mapView.viewWithTag(ViewTag.errorBanner) as? ErrorBannerView,
        let error
      else { return }
      banner.show(message: error.errorDescription ?? "An error occurred.")
    }
  }

#endif
