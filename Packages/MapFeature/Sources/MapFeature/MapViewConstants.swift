//
//  MapViewConstants.swift
//  MapFeature
//
//  Created by Davud Gunduz on 14.04.2026.
//

#if os(iOS) || os(visionOS)

  import MapKit

  // MARK: - ViewTag

  /// Stable integer tags for locating overlay subviews within `MKMapView`.
  ///
  /// Using tags avoids storing subview references across SwiftUI re-renders.
  /// All values are deliberately large (9000+) to avoid conflicting with any
  /// tags set by MapKit itself or UIKit system views.
  enum ViewTag {
    /// Tag for the `UIActivityIndicatorView` loading overlay.
    static let loadingIndicator = 9_001
    /// Tag for the ``ErrorBannerView`` error overlay.
    static let errorBanner = 9_002
    /// Tag for the ``CategoryChipBar`` filter bar.
    static let chipBar = 9_003
    /// Tag for the reverse-geocode city label.
    static let cityLabel = 9_004
  }

#endif

// MARK: - MKCoordinateRegion + ZoomLevel

#if canImport(MapKit)

  import MapKit

  extension MKCoordinateRegion {

    /// Converts the region's visible latitude span into an approximate
    /// web-Mercator zoom level (0 = world, 20 = building-level).
    ///
    /// This is the single source of truth for the zoom formula used both in
    /// `Coordinator.regionDidChangeAnimated` and the `CategoryChipBar` tap
    /// closure — previously duplicated in `NerveMapView.swift`.
    ///
    /// - Note: The returned value is a `Double` — callers should round or
    ///   floor as needed for clustering granularity thresholds.
    var approximateZoomLevel: Double {
      let latDelta = max(span.latitudeDelta, 0.001)
      return log2(360.0 / latDelta)
    }
  }

#endif
