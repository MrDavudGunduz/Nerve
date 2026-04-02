//
//  NerveMapView.swift
//  MapFeature
//
//  Created by Davud Gunduz on 02.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import MapKit
  import SwiftUI

  // MARK: - NerveMapView

  /// The primary SwiftUI-compatible map view for the Nerve app.
  ///
  /// Wraps `MKMapView` via `UIViewRepresentable` to support custom annotation
  /// views (`NewsAnnotationView`, `ClusterAnnotationView`) that are not yet
  /// available in the native SwiftUI `Map` API.
  ///
  /// ## Responsibilities
  /// - Registers ``NewsAnnotationView`` and ``ClusterAnnotationView`` reuse identifiers.
  /// - Forwards annotation selection events to a coordinator.
  /// - Drives clustering via ``AnnotationClusterer`` on visible-region changes.
  ///
  /// - Note: The clustering engine runs on ``AnnotationClusterer``'s background actor,
  ///   so main-thread map updates are dispatched via `Task { @MainActor in ... }`.
  public struct NerveMapView: UIViewRepresentable {

    // MARK: - Environment

    @Environment(\.dependencyContainer) private var container

    // MARK: - State

    /// The initial camera region centred on Istanbul.
    private static let defaultRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
      latitudinalMeters: 50_000,
      longitudinalMeters: 50_000
    )

    // MARK: - UIViewRepresentable

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeUIView(context: Context) -> MKMapView {
      let mapView = MKMapView()
      mapView.delegate = context.coordinator

      // Register custom annotation view classes so MKMapView can dequeue them.
      mapView.register(
        NewsAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: NewsAnnotation.singleReuseID
      )
      mapView.register(
        ClusterAnnotationView.self,
        forAnnotationViewWithReuseIdentifier: NewsAnnotation.clusterReuseID
      )

      mapView.setRegion(Self.defaultRegion, animated: false)
      mapView.showsUserLocation = true
      mapView.showsCompass = true
      mapView.pointOfInterestFilter = .excludingAll

      return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
      // Future: diff current annotations against new cluster results here.
      // The clustering cycle will be triggered by MKMapViewDelegate.regionDidChangeAnimated.
    }

    // MARK: - Coordinator

    /// Bridges MKMapViewDelegate callbacks into SwiftUI state updates.
    public final class Coordinator: NSObject, MKMapViewDelegate {

      // MARK: - Annotation Views

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

      // MARK: - Region Changes

      /// Triggers a new clustering pass whenever the visible region changes.
      public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Future: call AnnotationClusterer here, then diff annotations on map.
        // Stubbed for initial integration — real clustering will follow in a
        // dedicated `MapViewModel` that owns the clusterer reference.
      }

      // MARK: - Selection

      public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // Future: push article detail via NavigationStack path binding.
      }
    }
  }

  // MARK: - Preview

  #Preview {
    NerveMapView()
  }

#endif
