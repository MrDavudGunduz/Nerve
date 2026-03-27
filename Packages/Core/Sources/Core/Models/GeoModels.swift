//
//  GeoModels.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

// MARK: - GeoCoordinate

/// A geographic coordinate expressed as latitude and longitude.
///
/// This is the canonical representation of a point on Earth used
/// throughout Nerve. It is intentionally decoupled from CoreLocation's
/// `CLLocationCoordinate2D` to keep `Core` free of platform frameworks.
public struct GeoCoordinate: Sendable, Codable, Hashable {
    
  /// Latitude in decimal degrees (−90 … +90).
    public let latitude: Double

  /// Longitude in decimal degrees (−180 … +180).
    public let longitude: Double

  /// Creates a coordinate with the given latitude and longitude.
    
    public init(latitude: Double, longitude: Double) {
        
      precondition((-90...90).contains(latitude), "Latitude must be -90...+90")
      precondition((-180...180).contains(longitude), "Longitude must be -180...+180")
        
      self.latitude = latitude
      self.longitude = longitude
    }

}

// MARK: - GeoRegion

/// A circular geographic region defined by a center point and a radius.
///
/// Used to scope news queries to a specific area of interest.
public struct GeoRegion: Sendable, Codable, Hashable {

  /// The center point of the region.
  public let center: GeoCoordinate

  /// The radius of the region in meters.
  public let radiusMeters: Double

  /// Creates a region with the given center and radius.
  public init(center: GeoCoordinate, radiusMeters: Double) {
    self.center = center
    self.radiusMeters = radiusMeters
  }
}
