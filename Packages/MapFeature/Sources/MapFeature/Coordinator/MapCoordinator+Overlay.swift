//
//  MapCoordinator+Overlay.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import MapKit
  import UIKit

  extension NerveMapView.Coordinator {

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
  }

#endif
