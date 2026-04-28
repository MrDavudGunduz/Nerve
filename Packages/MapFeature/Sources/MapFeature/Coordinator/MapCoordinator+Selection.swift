//
//  MapCoordinator+Selection.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import MapKit
  import UIKit

  extension NerveMapView.Coordinator {

    /// Presents a ``NewsDetailSheet`` when any news annotation is selected.
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
      guard let newsAnnotation = view.annotation as? NewsAnnotation else { return }

      if let newsView = view as? NewsAnnotationView {
        newsView.setSelected(true, animated: true)
      }

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

#endif
