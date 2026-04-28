//
//  MapCoordinator.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import CoreLocation
  import MapKit

  // MARK: - NerveMapView.Coordinator

  extension NerveMapView {

    /// Bridges `MKMapViewDelegate` callbacks into ``MapViewModel`` updates.
    ///
    /// ## Responsibilities
    ///
    /// - Annotation view configuration and entrance/exit animations.
    /// - Debounced region-change handling (load vs. recluster decision).
    /// - Reverse-geocoding the visible center to display the city name.
    /// - Owning the location-tracking `Task` lifetime.
    ///
    /// ## File Organization
    ///
    /// The Coordinator's delegate conformance is split across focused extensions:
    /// - ``MapCoordinator+Annotations.swift`` — `viewFor` / `didAdd` delegates
    /// - ``MapCoordinator+Region.swift`` — `regionDidChange` + debounce + geocoding
    /// - ``MapCoordinator+Selection.swift`` — `didSelect` / `didDeselect` + sheet presentation
    public final class Coordinator: NSObject, MKMapViewDelegate {

      // MARK: - Constants

      /// Minimum radius change (in meters) before a full cache + network reload
      /// is triggered. Changes smaller than this threshold only trigger a recluster.
      static let regionChangeThreshold: Double = 5_000

      /// Region-change events fired during a pan gesture are collapsed into a
      /// single load/recluster call after this delay, preventing per-frame work.
      static let debounceDelay: Duration = .milliseconds(300)

      // MARK: - Properties

      let viewModel: MapViewModel

      /// Tracks the radius of the last region that triggered `loadNews`.
      var lastLoadedRadiusMeters: Double = 0

      /// Retained handle for the location-tracking `Task` — cancelled on `deinit`.
      var locationTask: Task<Void, Never>?

      /// Retained handle for the debounce `Task` — cancelled and replaced on
      /// every new `regionDidChangeAnimated` event.
      var debounceTask: Task<Void, Never>?

      /// Guards against overlapping `CLGeocoder` requests.
      var isGeocoding = false
      let geocoder = CLGeocoder()

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
    }
  }

#endif
