//
//  MapOverlayConfigurator.swift
//  MapFeature
//
//  Created by Davud Gunduz on 28.04.2026.
//

#if os(iOS) || os(visionOS)

  import Core
  import MapKit
  import UIKit

  // MARK: - MapOverlayConfigurator

  /// Configures all overlay subviews that are added on top of the `MKMapView`
  /// during ``NerveMapView/makeUIView(context:)``.
  ///
  /// ## Design Rationale
  ///
  /// Extracting overlay setup into a dedicated configurator achieves two goals:
  /// 1. **Single Responsibility**: `NerveMapView.makeUIView` stays lean —
  ///    it owns map *creation*, not layout details of four overlay subviews.
  /// 2. **Testability**: Each `install*` method can be unit-tested in isolation
  ///    with a bare `MKMapView` instance, without standing up the full
  ///    `UIViewRepresentable` lifecycle.
  ///
  /// All overlay views are located at runtime via ``ViewTag`` integer tags,
  /// so no subview references are stored across SwiftUI re-renders.
  @MainActor
  enum MapOverlayConfigurator {

    // MARK: - Full Installation

    /// Installs all overlay subviews onto the given map view in the correct
    /// z-order: loading indicator → error banner → category chip bar → city label.
    ///
    /// - Parameters:
    ///   - mapView: The `MKMapView` to add overlays onto.
    ///   - viewModel: The ``MapViewModel`` that drives chip bar state.
    static func installAllOverlays(on mapView: MKMapView, viewModel: MapViewModel) {
      installLoadingIndicator(on: mapView)
      installErrorBanner(on: mapView)
      installCategoryChipBar(on: mapView, viewModel: viewModel)
      installCityLabel(on: mapView)
    }

    // MARK: - Loading Indicator

    /// Installs a `UIActivityIndicatorView` centered horizontally at the top
    /// of the map's safe area.
    static func installLoadingIndicator(on mapView: MKMapView) {
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
    }

    // MARK: - Error Banner

    /// Installs an ``ErrorBannerView`` pinned to the top of the map's safe area.
    ///
    /// The banner starts with `alpha = 0` and is shown/hidden by
    /// ``MapStateUpdater`` during `updateUIView` passes.
    static func installErrorBanner(on mapView: MKMapView) {
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
    }

    // MARK: - Category Chip Bar

    /// Installs the ``CategoryChipBar`` at the top of the map and wires its
    /// region-lookup closure to the given `mapView`.
    ///
    /// The `onChipTapped` closure captures a `[weak mapView]` reference so
    /// the chip bar never needs to traverse the view hierarchy itself.
    static func installCategoryChipBar(on mapView: MKMapView, viewModel: MapViewModel) {
      let chipBar = CategoryChipBar(viewModel: viewModel)
      chipBar.tag = ViewTag.chipBar
      chipBar.translatesAutoresizingMaskIntoConstraints = false

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
    }

    // MARK: - City Label

    /// Installs the reverse-geocode city label anchored to the bottom-trailing
    /// corner of the map's safe area.
    ///
    /// Updated by ``MapCoordinator`` after each debounced reverse-geocode pass.
    static func installCityLabel(on mapView: MKMapView) {
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
    }
  }

#endif
