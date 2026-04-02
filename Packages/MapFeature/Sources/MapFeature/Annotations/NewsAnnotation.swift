//
//  NewsAnnotation.swift
//  MapFeature
//
//  Created by Davud Gunduz on 31.03.2026.
//

import Core
import Foundation
import MapKit

// MARK: - NewsAnnotation

/// A MapKit annotation that bridges a ``Core/NewsCluster`` to the map.
///
/// Each instance represents either a single news item or a merged
/// cluster of multiple items. The associated ``Core/NewsCluster``
/// provides all metadata needed for rendering and detail views.
///
/// Register with `MKMapView` via:
/// ```swift
/// mapView.register(
///   ClusterAnnotationView.self,
///   forAnnotationViewWithReuseIdentifier: NewsAnnotation.clusterReuseID
/// )
/// ```
// `@unchecked Sendable`: NSObject/MKAnnotation inheritance prevents the compiler
// from verifying Sendable automatically. Safety is guaranteed manually:
//   • All stored state is immutable (`let cluster: NewsCluster`).
//   • `NewsCluster` is a `Sendable` value type — no shared mutable references.
// If mutable stored properties are added in the future, add explicit synchronisation.
public final class NewsAnnotation: NSObject, MKAnnotation, @unchecked Sendable {

  // MARK: - Reuse Identifiers

  /// Reuse identifier for cluster annotation views.
  public static let clusterReuseID = "com.nerve.annotation.cluster"

  /// Reuse identifier for single-item annotation views.
  public static let singleReuseID = "com.nerve.annotation.single"

  // MARK: - Properties

  /// The cluster this annotation represents.
  public let cluster: NewsCluster

  // MARK: - MKAnnotation

  public var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: cluster.center.latitude,
      longitude: cluster.center.longitude
    )
  }

  public var title: String? {
    cluster.isCluster
      ? "\(cluster.count) stories"
      : cluster.representativeHeadline
  }

  public var subtitle: String? {
    cluster.isCluster
      ? cluster.dominantCategory.rawValue.capitalized
      : cluster.items.first?.source
  }

  // MARK: - Accessors

  /// The appropriate reuse identifier for this annotation.
  public var reuseIdentifier: String {
    cluster.isCluster ? Self.clusterReuseID : Self.singleReuseID
  }

  /// Short text for the cluster bubble glyph (e.g., "12").
  public var glyphText: String? {
    cluster.isCluster ? "\(cluster.count)" : nil
  }

  // MARK: - Init

  /// Creates an annotation from the given cluster.
  public init(cluster: NewsCluster) {
    self.cluster = cluster
    super.init()
  }
}
