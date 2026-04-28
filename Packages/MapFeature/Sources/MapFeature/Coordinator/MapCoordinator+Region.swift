//
//  MapCoordinator+Region.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import CoreLocation
  import MapKit
  import UIKit

  extension NerveMapView.Coordinator {

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

      debounceTask?.cancel()
      debounceTask = Task { @MainActor [weak self, weak mapView] in
        do {
          try await Task.sleep(for: Self.debounceDelay)
        } catch {
          return
        }
        guard let self, let mapView else { return }
        if isSignificantChange {
          self.lastLoadedRadiusMeters = geoRegion.radiusMeters
          await self.viewModel.loadNews(for: geoRegion, zoomLevel: zoomLevel)
        } else {
          await self.viewModel.recluster(in: geoRegion, zoomLevel: zoomLevel)
        }

        self.reverseGeocode(center: visibleRegion.center, mapView: mapView)
      }
    }

    private func reverseGeocode(center: CLLocationCoordinate2D, mapView: MKMapView) {
      guard !isGeocoding else { return }
      isGeocoding = true
      let clLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
      geocoder.reverseGeocodeLocation(clLocation) { [weak self, weak mapView] placemarks, _ in
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

#endif
