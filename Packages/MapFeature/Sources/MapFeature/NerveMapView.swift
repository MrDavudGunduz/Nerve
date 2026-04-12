//
//  NerveMapView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 02.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
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
  /// ## Loading & Error UI
  ///
  /// - `isLoading` → a `UIActivityIndicatorView` overlay is shown on the map.
  /// - `viewModel.error` → a self-dismissing banner slides in from the top.
  public struct NerveMapView: UIViewRepresentable {

    // MARK: - Init

    /// The view model driving map state.
    @State private var viewModel: MapViewModel

    /// Creates a map view backed by the given view model.
    ///
    /// - Parameter viewModel: The ``MapViewModel`` to observe.
    public init(viewModel: MapViewModel = MapViewModel()) {
      _viewModel = State(initialValue: viewModel)
    }

    // MARK: - State

    /// The initial camera region centred on Istanbul as a fallback.
    private static let fallbackRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      latitudinalMeters: 50_000,
      longitudinalMeters: 50_000
    )

    // MARK: - UIViewRepresentable

    /// Creates the delegate bridge that connects `MKMapViewDelegate` callbacks
    /// to ``MapViewModel`` state updates.
    public func makeCoordinator() -> Coordinator {
      Coordinator(viewModel: viewModel)
    }

    /// Creates and fully configures the underlying `MKMapView`.
    ///
    /// Sets up annotation reuse identifiers, overlays (loading spinner and
    /// error banner), and launches location tracking as a `Task`.
    public func makeUIView(context: Context) -> MKMapView {
      let mapView = MKMapView()
      mapView.delegate = context.coordinator

      // Register reuse identifiers.
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

      // Loading indicator overlay.
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

      // Error banner overlay.
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

      // Start location tracking on first appear.
      Task { @MainActor in
        await viewModel.startLocationTracking()
        // Centre on user location if available.
        if let userCoord = viewModel.userLocation {
          let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
              latitude: userCoord.latitude,
              longitude: userCoord.longitude
            ),
            latitudinalMeters: 50_000,
            longitudinalMeters: 50_000
          )
          mapView.setRegion(region, animated: true)
        }
      }

      return mapView
    }

    /// Syncs the map's annotations and overlay state with the current ViewModel snapshot.
    ///
    /// Called by SwiftUI whenever an `@Observable` property on `viewModel` changes.
    public func updateUIView(_ mapView: MKMapView, context: Context) {
      // ── Annotation Diffing ──
      let nextClusters = viewModel.clusters
      let nextByID = Dictionary(
        uniqueKeysWithValues: nextClusters.map { ($0.id, $0) }
      )
      let existing = mapView.annotations.compactMap { $0 as? NewsAnnotation }
      let existingIDs = Set(existing.map { $0.cluster.id })
      let nextIDs = Set(nextByID.keys)

      // ── Animated Removal ──
      // Cluster views animate out before the annotation is removed;
      // single-item pins are removed immediately (no collapse animation).
      let toRemove = existing.filter { !nextIDs.contains($0.cluster.id) }
      if !toRemove.isEmpty {
        var unanimated: [MKAnnotation] = []
        var delayedRemoval: [MKAnnotation] = []

        for annotation in toRemove {
          if annotation.cluster.isCluster,
            let view = mapView.view(for: annotation) as? ClusterAnnotationView
          {
            delayedRemoval.append(annotation)
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
        // delayedRemoval items are removed inside the completion closure above.
      }

      // ── Addition ──
      // mapView(_:didAdd:) in Coordinator triggers animateAppearance() for new cluster views.
      let newIDs = nextIDs.subtracting(existingIDs)
      let toAdd = newIDs.compactMap { nextByID[$0].map { NewsAnnotation(cluster: $0) } }
      if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }

      // ── Loading Indicator ──
      if let indicator = mapView.viewWithTag(ViewTag.loadingIndicator) as? UIActivityIndicatorView {
        viewModel.isLoading ? indicator.startAnimating() : indicator.stopAnimating()
      }

      // ── Error Banner ──
      if let banner = mapView.viewWithTag(ViewTag.errorBanner) as? ErrorBannerView,
        let error = viewModel.error
      {
        banner.show(message: error.errorDescription ?? "Bir hata oluştu.", in: mapView)
      }
    }

    // MARK: - Coordinator

    /// Bridges `MKMapViewDelegate` callbacks into ``MapViewModel`` updates.
    public final class Coordinator: NSObject, MKMapViewDelegate {

      private let viewModel: MapViewModel
      /// Minimum radius change (in meters) before triggering a data reload.
      private static let regionChangeThreshold: Double = 5_000

      init(viewModel: MapViewModel) {
        self.viewModel = viewModel
      }

      // MARK: Annotation Views

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

      // MARK: Appearance Animations

      /// Called by MapKit after annotation views are added to the map and laid out.
      /// This is the correct hook for entrance animations — views are already
      /// positioned, so transforms animate from a meaningful origin.
      public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views {
          if let clusterView = view as? ClusterAnnotationView {
            clusterView.animateAppearance()
          } else if let pinView = view as? NewsAnnotationView {
            // Single-pin entrance: subtle fade-in + scale.
            pinView.alpha = 0
            pinView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            UIView.animate(
              withDuration: 0.35, delay: 0,
              usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8,
              options: [.curveEaseOut]
            ) {
              pinView.alpha = 1
              pinView.transform = .identity
            }
          }
        }
      }

      // MARK: Region Changes

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

        let latDelta = max(visibleRegion.span.latitudeDelta, 0.001)
        let zoomLevel = log2(360.0 / latDelta)

        let isSignificantChange = geoRegion.radiusMeters > Self.regionChangeThreshold

        Task { @MainActor in
          if isSignificantChange {
            // Full cache + network load for significant pans or zoom-outs.
            await viewModel.loadNews(for: geoRegion, zoomLevel: zoomLevel)
          } else {
            // Cheap re-cluster only — reuse current items.
            await viewModel.recluster(in: geoRegion, zoomLevel: zoomLevel)
          }
        }
      }

      // MARK: Selection

      /// Forwards the selection event to the annotation view's spring animation.
      public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let newsView = view as? NewsAnnotationView else { return }
        newsView.setSelected(true, animated: true)
      }

      /// Reverses the selection animation when the annotation is deselected.
      public func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let newsView = view as? NewsAnnotationView else { return }
        newsView.setSelected(false, animated: true)
      }
    }

    // MARK: - View Tags

    /// Stable integer tags for locating overlay subviews within `MKMapView`.
    ///
    /// Using tags avoids storing subview references across SwiftUI re-renders.
    private enum ViewTag {
      /// Tag for the `UIActivityIndicatorView` loading overlay.
      static let loadingIndicator = 9_001
      /// Tag for the ``ErrorBannerView`` error overlay.
      static let errorBanner = 9_002
    }
  }

  // MARK: - ErrorBannerView

  /// A UIView-based dismissable error banner shown at the top of the map.
  ///
  /// Pure UIKit — avoids introducing SwiftUI hosting inside `UIViewRepresentable`.
  final class ErrorBannerView: UIView {

    private let label = UILabel()
    private var dismissTimer: Timer?

    override init(frame: CGRect) {
      super.init(frame: frame)
      setUp()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setUp() {
      backgroundColor = UIColor.systemRed.withAlphaComponent(0.92)
      layer.cornerRadius = 12
      layer.masksToBounds = true

      label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
      label.textColor = .white
      label.numberOfLines = 2
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      addSubview(label)
      NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      ])

      let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
      addGestureRecognizer(tap)
    }

    /// Displays the banner with the given message and starts a 4-second auto-dismiss timer.
    ///
    /// Calling `show` again while the banner is visible resets the dismiss timer.
    ///
    /// - Parameters:
    ///   - message: The error text to display (max two lines).
    ///   - superview: The view in whose coordinate space the banner is shown.
    func show(message: String, in superview: UIView) {
      label.text = message
      dismissTimer?.invalidate()
      UIView.animate(withDuration: 0.25) { self.alpha = 1 }
      dismissTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
        self?.dismiss()
      }
    }

    /// Immediately fades out the banner and cancels the dismiss timer.
    @objc private func dismiss() {
      dismissTimer?.invalidate()
      UIView.animate(withDuration: 0.25) { self.alpha = 0 }
    }
  }

  // MARK: - Preview

  #Preview {
    NerveMapView()
  }

#endif
