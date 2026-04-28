//
//  NerveMapView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 02.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import CoreLocation
  import MapKit
  import Observation
  import SwiftUI
  import UIKit

  // MARK: - NerveMapView

  /// The primary SwiftUI-compatible map view for the Nerve app.
  ///
  /// Wraps `MKMapView` via `UIViewRepresentable` to support custom annotation
  /// views (`NewsAnnotationView`, `ClusterAnnotationView`) that are not yet
  /// available in the native SwiftUI `Map` API.
  ///
  /// ## Data Flow
  ///
  /// 1. On first appear, `startLocationTracking()` is called — the map
  ///    centers on the user's live location when the first fix arrives.
  /// 2. `regionDidChangeAnimated` triggers `loadNews(for:zoomLevel:)` when
  ///    the delta is significant enough to warrant a cache/network round-trip,
  ///    or `recluster(in:zoomLevel:)` for minor pans.
  /// 3. `updateUIView` performs O(n) annotation diffing against `viewModel.clusters`.
  ///
  /// ## Overlay Views
  ///
  /// All overlay subviews (`UIActivityIndicatorView`, ``ErrorBannerView``,
  /// ``CategoryChipBar``, city label) are located via `ViewTag` integer tags,
  /// which avoids storing subview references across SwiftUI re-renders.
  ///
  /// ## File Organization
  ///
  /// Related types are separated into focused files:
  /// - ``MapOverlayConfigurator`` — Overlay installation factory
  /// - ``MapStateUpdater`` — updateUIView state synchronisation
  /// - ``Coordinator`` — `Coordinator/MapCoordinator.swift` + extensions
  /// - ``CategoryChipBar`` — `CategoryChipBar.swift`
  /// - ``ErrorBannerView`` — `ErrorBannerView.swift`
  /// - `ViewTag` / zoom helpers — `MapViewConstants.swift`
  /// - `UIView.viewController` — `MapViewHelpers.swift`
  public struct NerveMapView: UIViewRepresentable {

    // MARK: - State

    /// The view model driving map state.
    @State private var viewModel: MapViewModel

    /// The initial camera region centred on Istanbul as a fallback.
    private static let fallbackRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      latitudinalMeters: 50_000,
      longitudinalMeters: 50_000
    )

    // MARK: - Init

    /// Creates a map view backed by the given view model.
    ///
    /// - Parameter viewModel: The ``MapViewModel`` to observe.
    ///   Defaults to a preview-safe instance with stub services.
    public init(viewModel: MapViewModel = MapViewModel()) {
      _viewModel = State(initialValue: viewModel)
    }

    // MARK: - UIViewRepresentable

    /// Creates the delegate bridge that connects `MKMapViewDelegate` callbacks
    /// to ``MapViewModel`` state updates.
    public func makeCoordinator() -> Coordinator {
      Coordinator(viewModel: viewModel)
    }

    /// Creates and fully configures the underlying `MKMapView`.
    ///
    /// Delegates overlay installation to ``MapOverlayConfigurator`` and
    /// launches location tracking via the ``Coordinator``.
    public func makeUIView(context: Context) -> MKMapView {
      let mapView = MKMapView()
      mapView.delegate = context.coordinator

      // ── Annotation Reuse Registration ──
      mapView.register(
        NewsAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: NewsAnnotation.singleReuseID
      )
      mapView.register(
        ClusterAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: NewsAnnotation.clusterReuseID
      )

      mapView.setRegion(Self.fallbackRegion, animated: false)
      mapView.showsUserLocation = true
      mapView.showsCompass = true
      mapView.pointOfInterestFilter = .excludingAll

      // ── Overlay Installation (delegated to configurator) ──
      MapOverlayConfigurator.installAllOverlays(on: mapView, viewModel: viewModel)

      // ── Start Location Tracking ──
      context.coordinator.startLocationTask(mapView: mapView)

      return mapView
    }

    /// Syncs the map's annotations and overlay state with the current
    /// ViewModel snapshot via ``MapStateUpdater``.
    ///
    /// Called by SwiftUI whenever an `@Observable` property on `viewModel` changes.
    public func updateUIView(_ mapView: MKMapView, context: Context) {
      MapStateUpdater.diffAnnotations(on: mapView, clusters: viewModel.clusters)
      MapStateUpdater.updateSkeletonState(on: mapView, isLoading: viewModel.isLoading)
      MapStateUpdater.updateMapStyle(on: mapView, coordinator: context.coordinator)
      MapStateUpdater.updateUserLocationOverlay(
        on: mapView, coordinator: context.coordinator, userLocation: viewModel.userLocation)
      MapStateUpdater.updateLoadingIndicator(on: mapView, isLoading: viewModel.isLoading)
      MapStateUpdater.updateErrorBanner(on: mapView, error: viewModel.error)
    }
  }

  // MARK: - Preview

  #Preview {
    NerveMapView()
  }

#endif
