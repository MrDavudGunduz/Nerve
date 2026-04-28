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
    /// Sets up annotation reuse identifiers, overlay subviews (loading spinner,
    /// error banner, category chip bar, city label), and launches location
    /// tracking as a `Task` stored on the `Coordinator`.
    public func makeUIView(context: Context) -> MKMapView {
      let mapView = MKMapView()
      mapView.delegate = context.coordinator

      // ── Annotation Reuse ──
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

      // ── Loading Indicator Overlay ──
      let indicator = UIActivityIndicatorView(style: .medium)
      indicator.tag = ViewTag.loadingIndicator
      indicator.translatesAutoresizingMaskIntoConstraints = false
      indicator.hidesWhenStopped = true
      mapView.addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.centerXAnchor),
        indicator.topAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 12),
      ])

      // ── Error Banner Overlay ──
      let banner = ErrorBannerView()
      banner.tag = ViewTag.errorBanner
      banner.translatesAutoresizingMaskIntoConstraints = false
      banner.alpha = 0
      mapView.addSubview(banner)
      NSLayoutConstraint.activate([
        banner.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
        banner.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 8),
        banner.leadingAnchor.constraint(equalTo: mapView.leadingAnchor, constant: 16),
        banner.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
      ])

      // ── Category Filter Chip Bar ──
      let chipBar = CategoryChipBar(viewModel: viewModel)
      chipBar.tag = ViewTag.chipBar
      chipBar.translatesAutoresizingMaskIntoConstraints = false

      // Provide the chip bar with the current MKMapView region via a closure so it
      // never needs to cast `superview` to `MKMapView` directly.
      chipBar.onChipTapped = { [weak mapView] in
        guard let mapView else { return nil }
        let region = mapView.region
        guard
          let center = GeoCoordinate(
            latitude: region.center.latitude,
            longitude: region.center.longitude),
          let geoRegion = GeoRegion(
            center: center,
            radiusMeters: region.span.latitudeDelta * 111_000 / 2)
        else { return nil }
        return (geoRegion, region.approximateZoomLevel)
      }

      mapView.addSubview(chipBar)
      NSLayoutConstraint.activate([
        chipBar.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 8),
        chipBar.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
        chipBar.trailingAnchor.constraint(equalTo: mapView.trailingAnchor),
        chipBar.heightAnchor.constraint(equalToConstant: 40),
      ])

      // ── Region City Label ──
      let cityLabel = UILabel()
      cityLabel.tag = ViewTag.cityLabel
      cityLabel.font = .systemFont(ofSize: 12, weight: .semibold)
      cityLabel.textColor = .secondaryLabel
      cityLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.75)
      cityLabel.layer.cornerRadius = 8
      cityLabel.layer.masksToBounds = true
      cityLabel.textAlignment = .center
      cityLabel.translatesAutoresizingMaskIntoConstraints = false
      cityLabel.isUserInteractionEnabled = false
      mapView.addSubview(cityLabel)
      NSLayoutConstraint.activate([
        cityLabel.trailingAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
        cityLabel.bottomAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        cityLabel.heightAnchor.constraint(equalToConstant: 28),
        cityLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 180),
      ])

      // Start location tracking — Task is stored in Coordinator to prevent leaks.
      context.coordinator.startLocationTask(mapView: mapView)

      return mapView
    }

    /// Syncs the map's annotations and overlay state with the current ViewModel snapshot.
    ///
    /// Called by SwiftUI whenever an `@Observable` property on `viewModel` changes.
    public func updateUIView(_ mapView: MKMapView, context: Context) {

      // ── Annotation Diffing ──
      let nextClusters = viewModel.clusters
      let nextByID = Dictionary(uniqueKeysWithValues: nextClusters.map { ($0.id, $0) })
      let existing = mapView.annotations.compactMap { $0 as? NewsAnnotation }
      let existingIDs = Set(existing.map { $0.cluster.id })
      let nextIDs = Set(nextByID.keys)

      // ── Animated Removal ──
      // Cluster views animate out before the annotation is removed;
      // single-item pins are removed immediately (no collapse animation).
      let toRemove = existing.filter { !nextIDs.contains($0.cluster.id) }
      if !toRemove.isEmpty {
        var unanimated: [MKAnnotation] = []

        for annotation in toRemove {
          if annotation.cluster.isCluster,
            let view = mapView.view(for: annotation) as? ClusterAnnotationView
          {
            view.animateDisappearance {
              // Remove on main thread after animation completes.
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
      // mapView(_:didAdd:) in Coordinator triggers animateAppearance() for new cluster views.
      let newIDs = nextIDs.subtracting(existingIDs)
      let toAdd = newIDs.compactMap { nextByID[$0].map { NewsAnnotation(cluster: $0) } }
      if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }

      // ── Skeleton Loading State ──
      let allViews = mapView.annotations.compactMap { mapView.view(for: $0) }
      if viewModel.isLoading {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.showSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.showSkeleton() }
      } else {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.hideSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.hideSkeleton() }
      }

      // ── Adaptive Map Style (light / dark) ──
      // Only update when the interface style has actually changed.
      let currentStyle = mapView.traitCollection.userInterfaceStyle
      if currentStyle != context.coordinator.lastInterfaceStyle {
        context.coordinator.lastInterfaceStyle = currentStyle
        let mapConfig =
          currentStyle == .dark
          ? MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
          : MKStandardMapConfiguration()
        mapConfig.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = mapConfig
      }

      // ── User Location Pulse Ring ──
      // Only update the overlay when the user's location has actually changed
      // to avoid unnecessary remove/add churn on every @Observable mutation.
      if let coord = viewModel.userLocation,
        coord != context.coordinator.lastUserLocation
      {
        context.coordinator.lastUserLocation = coord
        let clCoord = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        let existingCircles = mapView.overlays.compactMap { $0 as? MKCircle }
        if !existingCircles.isEmpty {
          mapView.removeOverlays(existingCircles)
        }
        mapView.addOverlay(MKCircle(center: clCoord, radius: 150), level: .aboveRoads)
      }

      // ── Loading Indicator ──
      if let indicator = mapView.viewWithTag(ViewTag.loadingIndicator) as? UIActivityIndicatorView {
        viewModel.isLoading ? indicator.startAnimating() : indicator.stopAnimating()
      }

      // ── Error Banner ──
      if let banner = mapView.viewWithTag(ViewTag.errorBanner) as? ErrorBannerView,
        let error = viewModel.error
      {
        banner.show(message: error.errorDescription ?? "An error occurred.")
      }
    }
  }

  // MARK: - Coordinator

  extension NerveMapView {

    /// Bridges `MKMapViewDelegate` callbacks into ``MapViewModel`` updates.
    ///
    /// ## Responsibilities
    ///
    /// - Annotation view configuration and entrance/exit animations.
    /// - Debounced region-change handling (load vs. recluster decision).
    /// - Reverse-geocoding the visible center to display the city name.
    /// - Owning the location-tracking `Task` lifetime.
    public final class Coordinator: NSObject, MKMapViewDelegate {

      // MARK: - Constants

      /// Minimum radius change (in meters) before a full cache + network reload
      /// is triggered. Changes smaller than this threshold only trigger a recluster.
      private static let regionChangeThreshold: Double = 5_000

      /// Region-change events fired during a pan gesture are collapsed into a
      /// single load/recluster call after this delay, preventing per-frame work.
      private static let debounceDelay: Duration = .milliseconds(300)

      // MARK: - Properties

      private let viewModel: MapViewModel

      /// Tracks the radius of the last region that triggered `loadNews`.
      private var lastLoadedRadiusMeters: Double = 0

      /// Retained handle for the location-tracking `Task` — cancelled on `deinit`.
      private var locationTask: Task<Void, Never>?

      /// Retained handle for the debounce `Task` — cancelled and replaced on
      /// every new `regionDidChangeAnimated` event.
      private var debounceTask: Task<Void, Never>?

      /// Guards against overlapping `CLGeocoder` requests.
      private var isGeocoding = false
      private let geocoder = CLGeocoder()

      /// Tracks the last interface style to avoid redundant map config updates.
      var lastInterfaceStyle: UIUserInterfaceStyle = .unspecified

      /// Tracks the last user location to avoid redundant overlay remove/add
      /// cycles on every `@Observable` state mutation.
      var lastUserLocation: GeoCoordinate?

      // MARK: - Init

      init(viewModel: MapViewModel) {
        self.viewModel = viewModel
      }

      deinit {
        locationTask?.cancel()
        debounceTask?.cancel()
      }

      // MARK: - Location Task

      /// Starts location tracking and stores the `Task` to prevent memory leaks.
      func startLocationTask(mapView: MKMapView) {
        locationTask = Task { @MainActor [weak self, weak mapView] in
          guard let self, let mapView else { return }
          await self.viewModel.startLocationTracking()
          if let userCoord = self.viewModel.userLocation {
            let region = MKCoordinateRegion(
              center: CLLocationCoordinate2D(
                latitude: userCoord.latitude, longitude: userCoord.longitude),
              latitudinalMeters: 50_000,
              longitudinalMeters: 50_000
            )
            mapView.setRegion(region, animated: true)
          }
        }
      }

      // MARK: - MKMapViewDelegate: Annotation Views

      public func mapView(
        _ mapView: MKMapView,
        viewFor annotation: MKAnnotation
      ) -> MKAnnotationView? {
        guard let newsAnnotation = annotation as? NewsAnnotation else { return nil }

        if newsAnnotation.cluster.isCluster {
          let view =
            mapView.dequeueReusableAnnotationView(
              withIdentifier: NewsAnnotation.clusterReuseID,
              for: newsAnnotation
            ) as? ClusterAnnotationView
          view?.configure(with: newsAnnotation.cluster)
          return view
        } else {
          let view =
            mapView.dequeueReusableAnnotationView(
              withIdentifier: NewsAnnotation.singleReuseID,
              for: newsAnnotation
            ) as? NewsAnnotationView
          view?.configure(with: newsAnnotation.cluster)
          return view
        }
      }

      // MARK: - MKMapViewDelegate: Appearance Animations

      /// Called by MapKit after annotation views are added to the map and laid out.
      ///
      /// This is the correct hook for entrance animations — views are already
      /// positioned, so transforms animate from a meaningful origin point.
      public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views {
          if let clusterView = view as? ClusterAnnotationView {
            clusterView.animateAppearance()
          } else if let pinView = view as? NewsAnnotationView {
            // Single-pin entrance: subtle fade-in + spring scale.
            pinView.alpha = 0
            pinView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            UIView.animate(springDuration: 0.45, bounce: 0.3, initialSpringVelocity: 0.8) {
              pinView.alpha = 1
              pinView.transform = .identity
            }
          }
        }
      }

      // MARK: - MKMapViewDelegate: Region Changes

      public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let visibleRegion = mapView.region
        guard
          let center = GeoCoordinate(
            latitude: visibleRegion.center.latitude,
            longitude: visibleRegion.center.longitude
          ),
          let geoRegion = GeoRegion(
            center: center,
            radiusMeters: visibleRegion.span.latitudeDelta * 111_000 / 2
          )
        else { return }

        let zoomLevel = visibleRegion.approximateZoomLevel
        let radiusDelta = abs(geoRegion.radiusMeters - lastLoadedRadiusMeters)
        let isSignificantChange = radiusDelta > Self.regionChangeThreshold

        // Debounce: cancel any pending work and restart the 300 ms timer.
        // This collapses rapid pan/zoom events into a single load or recluster
        // call, preventing per-frame network and clustering work.
        // Reverse geocoding is also coalesced here to respect Apple's ~50 req/min
        // rate limit on CLGeocoder.
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self, weak mapView] in
          do {
            try await Task.sleep(for: Self.debounceDelay)
          } catch {
            return  // Cancelled — a newer region change supersedes this one.
          }
          guard let self, let mapView else { return }
          if isSignificantChange {
            self.lastLoadedRadiusMeters = geoRegion.radiusMeters
            await self.viewModel.loadNews(for: geoRegion, zoomLevel: zoomLevel)
          } else {
            await self.viewModel.recluster(in: geoRegion, zoomLevel: zoomLevel)
          }

          // ── Reverse Geocoding (city label) ──
          // Runs after debounce settles — prevents CLGeocoder rate-limit errors
          // during aggressive pan gestures.
          guard !self.isGeocoding else { return }
          self.isGeocoding = true
          let clLocation = CLLocation(
            latitude: visibleRegion.center.latitude,
            longitude: visibleRegion.center.longitude
          )
          self.geocoder.reverseGeocodeLocation(clLocation) { [weak self, weak mapView] placemarks, _
          in
            guard let self, let mapView else { return }
            self.isGeocoding = false
            let place = placemarks?.first
            let cityText = place?.locality ?? place?.administrativeArea ?? ""
            Task { @MainActor [weak mapView] in
              guard let mapView else { return }
              if let cityLabel = mapView.viewWithTag(ViewTag.cityLabel) as? UILabel {
                cityLabel.text = cityText.isEmpty ? nil : "  \(cityText)  "
              }
            }
          }
        }
      }

      // MARK: - MKMapViewDelegate: Overlay Rendering

      /// Provides renderers for map overlays.
      ///
      /// Returns a styled `MKCircleRenderer` for the user-location pulse ring.
      /// Without this method, `MKCircle` overlays are silently not rendered.
      public func mapView(
        _ mapView: MKMapView,
        rendererFor overlay: MKOverlay
      ) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
          let renderer = MKCircleRenderer(circle: circle)
          renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.08)
          renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.25)
          renderer.lineWidth = 1.0
          return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
      }

      // MARK: - MKMapViewDelegate: Selection

      /// Presents a ``NewsDetailSheet`` when any news annotation is selected.
      ///
      /// For single-item annotations, a selection spring animation is also played.
      /// The sheet is presented via `UISheetPresentationController` with
      /// `.medium()` and `.large()` detents for a native bottom-sheet UX.
      public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let newsAnnotation = view.annotation as? NewsAnnotation else { return }

        // Single-pin selection animation.
        if let newsView = view as? NewsAnnotationView {
          newsView.setSelected(true, animated: true)
        }

        // Present the detail sheet for both single items and clusters.
        let sheet = NewsDetailSheet(cluster: newsAnnotation.cluster)
        sheet.modalPresentationStyle = .pageSheet
        if let sheetController = sheet.sheetPresentationController {
          sheetController.detents = [.medium(), .large()]
          sheetController.prefersGrabberVisible = true
          sheetController.preferredCornerRadius = 20
        }

        mapView.viewController?.present(sheet, animated: true)
      }

      /// Reverses the selection animation when the annotation is deselected.
      public func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let newsView = view as? NewsAnnotationView else { return }
        newsView.setSelected(false, animated: true)
      }
    }
  }

  // MARK: - Preview

  #Preview {
    NerveMapView()
  }

#endif
