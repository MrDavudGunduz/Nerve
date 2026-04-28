//
//  MapCoordinator+Annotations.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import MapKit
  import UIKit

  // MARK: - Annotation View Configuration

  extension NerveMapView.Coordinator {

    // MARK: - viewFor Annotation

    /// Dequeues and configures the appropriate annotation view — either a
    /// ``ClusterAnnotationView`` for multi-item clusters or a ``NewsAnnotationView``
    /// for single items.
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

    // MARK: - Appearance Animations

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
  }

#endif
