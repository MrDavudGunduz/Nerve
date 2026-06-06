//
//  GeoModels.swift
//  Core
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Foundation

// MARK: - GeoCoordinate

/// A geographic coordinate expressed as latitude and longitude.
///
/// This is the canonical representation of a point on Earth used
/// throughout Nerve. It is intentionally decoupled from CoreLocation's
/// `CLLocationCoordinate2D` to keep `Core` free of platform frameworks.
///
/// Uses a failable initializer to gracefully reject invalid values
/// instead of crashing at runtime.
///
/// ```swift
/// guard let coord = GeoCoordinate(latitude: 41.0, longitude: 29.0) else {
///   throw NerveError.location(message: "Invalid coordinate")
/// }
/// ```
public struct GeoCoordinate: Sendable, Hashable {

  /// Latitude in decimal degrees (−90 … +90).
  public let latitude: Double

  /// Longitude in decimal degrees (−180 … +180).
  public let longitude: Double

  /// Creates a coordinate with the given latitude and longitude.
  ///
  /// Returns `nil` if either value is outside the valid geographic range.
  ///
  /// - Parameters:
  ///   - latitude: Latitude in decimal degrees (−90 … +90).
  ///   - longitude: Longitude in decimal degrees (−180 … +180).
  public init?(latitude: Double, longitude: Double) {
    guard (-90...90).contains(latitude),
      (-180...180).contains(longitude)
    else { return nil }

    self.latitude = latitude
    self.longitude = longitude
  }
}

// MARK: - Codable

extension GeoCoordinate: Codable {

  private enum CodingKeys: String, CodingKey {
    case latitude
    case longitude
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let lat = try container.decode(Double.self, forKey: .latitude)
    let lon = try container.decode(Double.self, forKey: .longitude)

    guard let coordinate = GeoCoordinate(latitude: lat, longitude: lon) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription:
            "Invalid coordinate: latitude \(lat) must be in −90…+90, "
            + "longitude \(lon) must be in −180…+180."
        )
      )
    }

    self = coordinate
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(latitude, forKey: .latitude)
    try container.encode(longitude, forKey: .longitude)
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

  /// Maximum allowable radius in meters (half of Earth's circumference ≈ 20,038 km).
  ///
  /// Any radius exceeding this value is physically meaningless on Earth
  /// and would cause the persistence layer to perform full-table scans.
  public static let maxRadiusMeters: Double = 20_038_000

  /// Creates a region with the given center and radius.
  ///
  /// Returns `nil` if `radiusMeters` is zero, negative, or exceeds
  /// ``maxRadiusMeters`` (Earth's half-circumference).
  ///
  /// - Parameters:
  ///   - center: The center point of the region.
  ///   - radiusMeters: The radius in meters (must be in `0 ..< maxRadiusMeters`).
  public init?(center: GeoCoordinate, radiusMeters: Double) {
    guard radiusMeters > 0, radiusMeters <= Self.maxRadiusMeters else { return nil }
    self.center = center
    self.radiusMeters = radiusMeters
  }

  // MARK: - Bounding Box

  /// An axis-aligned bounding box in geographic coordinates.
  ///
  /// Used by both ``NetworkLayer`` and ``StorageLayer`` for spatial queries.
  /// Centralizing the computation here eliminates formula duplication and
  /// ensures consistent bounding-box semantics across the codebase.
  public struct BoundingBox: Sendable, Hashable {
    /// Minimum latitude of the bounding box.
    public let minLatitude: Double
    /// Maximum latitude of the bounding box.
    public let maxLatitude: Double
    /// Minimum longitude of the bounding box.
    public let minLongitude: Double
    /// Maximum longitude of the bounding box.
    public let maxLongitude: Double
  }

  /// Computes an approximate bounding box for this region.
  ///
  /// The approximation uses:
  /// - 1° latitude ≈ 111 km
  /// - Longitude scaling by `cos(latitude)` to account for meridian convergence
  ///
  /// A floor of `0.01` on `cos(latitude)` guards against division-by-zero
  /// at polar latitudes (cos(90°) = 0), capping the bounding box to a
  /// reasonable maximum width.
  ///
  /// This is an **approximation** — downstream consumers (e.g., the clustering
  /// engine) perform exact spatial filtering when precision matters.
  public var boundingBox: BoundingBox {
    let latDelta = radiusMeters / 111_000
    let cosLat = max(cos(center.latitude * .pi / 180), 0.01)
    let lonDelta = radiusMeters / (111_000 * cosLat)

    return BoundingBox(
      minLatitude: center.latitude - latDelta,
      maxLatitude: center.latitude + latDelta,
      minLongitude: center.longitude - lonDelta,
      maxLongitude: center.longitude + lonDelta
    )
  }
}
