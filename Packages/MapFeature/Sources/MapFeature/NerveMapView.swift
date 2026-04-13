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
            latitude: region.center.latitude, longitude: region.center.longitude),
          let geoRegion = GeoRegion(
            center: center, radiusMeters: region.span.latitudeDelta * 111_000 / 2)
        else { return nil }
        let latDelta = max(region.span.latitudeDelta, 0.001)
        let zoomLevel = log2(360.0 / latDelta)
        return (geoRegion, zoomLevel)
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

      // ── Loading: Skeleton on existing annotations ──
      let allViews = mapView.annotations.compactMap { mapView.view(for: $0) }
      if viewModel.isLoading {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.showSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.showSkeleton() }
      } else {
        allViews.compactMap { $0 as? ClusterAnnotationView }.forEach { $0.hideSkeleton() }
        allViews.compactMap { $0 as? NewsAnnotationView }.forEach { $0.hideSkeleton() }
      }

      // ── Adaptive Map Style ──
      let isDark = mapView.traitCollection.userInterfaceStyle == .dark
      let mapConfig =
        isDark
        ? MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        : MKStandardMapConfiguration()
      mapConfig.pointOfInterestFilter = .excludingAll
      mapView.preferredConfiguration = mapConfig

      // ── User Location Pulse Ring ──
      if let coord = viewModel.userLocation {
        let clCoord = CLLocationCoordinate2D(
          latitude: coord.latitude, longitude: coord.longitude)
        let overlays = mapView.overlays.compactMap { $0 as? MKCircle }
        if overlays.isEmpty {
          mapView.addOverlay(
            MKCircle(center: clCoord, radius: 150), level: .aboveRoads)
        }
      }

      // ── Loading Indicator ──
      if let indicator = mapView.viewWithTag(ViewTag.loadingIndicator)
        as? UIActivityIndicatorView
      {
        viewModel.isLoading ? indicator.startAnimating() : indicator.stopAnimating()
      }

      // ── Error Banner ──
      if let banner = mapView.viewWithTag(ViewTag.errorBanner) as? ErrorBannerView,
        let error = viewModel.error
      {
        banner.show(message: error.errorDescription ?? "An error occurred.")
      }
    }

    // MARK: - Coordinator

    /// Bridges `MKMapViewDelegate` callbacks into ``MapViewModel`` updates.
    public final class Coordinator: NSObject, MKMapViewDelegate {

      private let viewModel: MapViewModel

      /// Minimum radius change (meters) relative to the last loaded region
      /// before triggering a full cache + network reload.
      private static let regionChangeThreshold: Double = 5_000

      /// Debounce delay — region-change events fired during a pan gesture are
      /// collapsed into a single load/recluster call 300 ms after the gesture
      /// settles, preventing per-frame network and clustering work.
      private static let debounceDelay: Duration = .milliseconds(300)

      /// Tracks the radius of the last region that triggered `loadNews`.
      private var lastLoadedRadiusMeters: Double = 0

      /// Retained reference to the location-tracking Task.
      private var locationTask: Task<Void, Never>?

      /// Retained reference to the debounce Task for region changes.
      /// Cancelled and replaced on every new `regionDidChangeAnimated` event.
      private var debounceTask: Task<Void, Never>?

      /// Prevents overlapping CLGeocoder requests.
      private var isGeocoding = false
      private let geocoder = CLGeocoder()

      init(viewModel: MapViewModel) {
        self.viewModel = viewModel
      }

      deinit {
        locationTask?.cancel()
        debounceTask?.cancel()
      }

      /// Starts location tracking; stores the Task so it can be cancelled on deinit.
      func startLocationTask(mapView: MKMapView) {
        locationTask = Task { @MainActor [weak self, weak mapView] in
          guard let self, let mapView else { return }
          await self.viewModel.startLocationTracking()
          if let userCoord = self.viewModel.userLocation {
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
            UIView.animate(springDuration: 0.45, bounce: 0.3, initialSpringVelocity: 0.8) {
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
        let radiusDelta = abs(geoRegion.radiusMeters - lastLoadedRadiusMeters)
        let isSignificantChange = radiusDelta > Self.regionChangeThreshold

        // Debounce: cancel any pending work and restart the 300 ms timer.
        // This collapses rapid pan/zoom events into a single load or recluster
        // call, preventing per-frame network and clustering work.
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
          do {
            try await Task.sleep(for: Self.debounceDelay)
          } catch {
            return  // Cancelled — a newer region change supersedes this one.
          }
          guard let self else { return }
          if isSignificantChange {
            self.lastLoadedRadiusMeters = geoRegion.radiusMeters
            await self.viewModel.loadNews(for: geoRegion, zoomLevel: zoomLevel)
          } else {
            await self.viewModel.recluster(in: geoRegion, zoomLevel: zoomLevel)
          }
        }

        // Reverse-geocode the center to update the city label.
        guard !isGeocoding else { return }
        isGeocoding = true
        let clLocation = CLLocation(
          latitude: visibleRegion.center.latitude,
          longitude: visibleRegion.center.longitude)
        geocoder.reverseGeocodeLocation(clLocation) { [weak self, weak mapView] placemarks, _ in
          guard let self, let mapView else { return }
          self.isGeocoding = false
          let place = placemarks?.first
          let cityText = place?.locality ?? place?.administrativeArea ?? ""
          DispatchQueue.main.async {
            if let cityLabel = mapView.viewWithTag(ViewTag.cityLabel) as? UILabel {
              cityLabel.text = cityText.isEmpty ? nil : "  \(cityText)  "
            }
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
      /// Tag for the ``CategoryChipBar`` filter bar.
      static let chipBar = 9_003
      /// Tag for the reverse-geocode city label.
      static let cityLabel = 9_004
    }
  }

  // MARK: - UIView+ViewController

  extension UIView {
    /// Walks the responder chain to find the nearest presenting `UIViewController`.
    fileprivate var viewController: UIViewController? {
      var responder: UIResponder? = self
      while let r = responder {
        if let vc = r as? UIViewController { return vc }
        responder = r.next
      }
      return nil
    }
  }

  // MARK: - CategoryChipBar

  /// A horizontally-scrolling row of category filter chips.
  ///
  /// Each chip toggles its category in ``MapViewModel/selectedCategories``
  /// and immediately triggers a re-cluster of visible items.
  ///
  /// A special **"All"** chip at the start clears all filters when tapped.
  ///
  /// The caller provides the current map region and zoom level through the
  /// ``onChipTapped`` closure, avoiding any fragile superview-cast assumptions.
  @MainActor
  final class CategoryChipBar: UIScrollView {

    // MARK: - Private

    private let viewModel: MapViewModel

    /// Called when the user taps a chip.
    /// The closure should return the current `GeoRegion` and zoom level
    /// based on the map's visible rect at tap time.
    var onChipTapped: (() -> (GeoRegion, Double)?)?

    private let stack: UIStackView = {
      let s = UIStackView()
      s.axis = .horizontal
      s.spacing = 8
      s.alignment = .center
      return s
    }()

    private var chipButtons: [UIButton] = []

    // MARK: - Init

    init(viewModel: MapViewModel) {
      self.viewModel = viewModel
      super.init(frame: .zero)
      showsHorizontalScrollIndicator = false
      showsVerticalScrollIndicator = false
      contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
      buildChips()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildChips() {
      stack.translatesAutoresizingMaskIntoConstraints = false
      addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: topAnchor),
        stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        stack.leadingAnchor.constraint(equalTo: leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        stack.heightAnchor.constraint(equalTo: heightAnchor),
      ])

      // "All" chip
      let allChip = makeChip(title: "All", tag: -1)
      stack.addArrangedSubview(allChip)
      chipButtons.append(allChip)

      // Category chips
      for (index, category) in NewsCategory.allCases.enumerated() {
        let chip = makeChip(
          title: category.rawValue.capitalized,
          tag: index,
          color: ClusterAnnotationView.color(for: category))
        stack.addArrangedSubview(chip)
        chipButtons.append(chip)
      }

      updateSelection()
    }

    private func makeChip(
      title: String,
      tag: Int,
      color: UIColor = .systemGray
    ) -> UIButton {
      var config = UIButton.Configuration.filled()
      config.title = title
      config.baseBackgroundColor = color.withAlphaComponent(0.85)
      config.baseForegroundColor = .white
      config.cornerStyle = .capsule
      config.contentInsets = NSDirectionalEdgeInsets(
        top: 6, leading: 14, bottom: 6, trailing: 14)
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
        var a = attrs
        a.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        return a
      }
      let btn = UIButton(configuration: config)
      btn.tag = tag
      btn.layer.shadowColor = UIColor.black.cgColor
      btn.layer.shadowOpacity = 0.15
      btn.layer.shadowRadius = 3
      btn.layer.shadowOffset = CGSize(width: 0, height: 1)
      btn.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
      return btn
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
      // Ask the caller for the current region + zoom level via the closure.
      // This removes the fragile `superview as? MKMapView` cast and keeps
      // the chip bar decoupled from its position in the view hierarchy.
      guard let (geoRegion, zoomLevel) = onChipTapped?() else { return }

      if sender.tag == -1 {
        Task { @MainActor [weak self] in
          guard let self else { return }
          await viewModel.clearCategoryFilter(in: geoRegion, zoomLevel: zoomLevel)
          updateSelection()
        }
      } else {
        let category = NewsCategory.allCases[sender.tag]
        Task { @MainActor [weak self] in
          guard let self else { return }
          await viewModel.toggleCategory(category, in: geoRegion, zoomLevel: zoomLevel)
          updateSelection()
        }
      }
    }

    // MARK: - State Sync

    private func updateSelection() {
      let selected = viewModel.selectedCategories
      for btn in chipButtons {
        if btn.tag == -1 {
          let isAll = selected.isEmpty
          var config = btn.configuration
          config?.baseBackgroundColor =
            isAll
            ? UIColor.label.withAlphaComponent(0.85)
            : UIColor.systemGray.withAlphaComponent(0.70)
          btn.configuration = config
        } else {
          let category = NewsCategory.allCases[btn.tag]
          let isActive = selected.contains(category)
          var config = btn.configuration
          let base = ClusterAnnotationView.color(for: category)
          config?.baseBackgroundColor = isActive ? base : base.withAlphaComponent(0.40)
          btn.configuration = config
        }
      }
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
    /// The timer is scheduled on `.common` RunLoop mode so it fires correctly
    /// even while the user is scrolling or interacting with the map.
    ///
    /// - Parameter message: The error text to display (max two lines).
    func show(message: String) {
      label.text = message
      dismissTimer?.invalidate()
      UIView.animate(withDuration: 0.25) { self.alpha = 1 }
      dismissTimer = Timer(
        timeInterval: 4,
        target: self,
        selector: #selector(dismiss),
        userInfo: nil,
        repeats: false
      )
      // Schedule on .common so the timer fires during map panning/scrolling.
      RunLoop.main.add(dismissTimer!, forMode: .common)
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
