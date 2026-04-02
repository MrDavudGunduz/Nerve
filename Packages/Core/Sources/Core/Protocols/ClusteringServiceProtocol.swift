//
//  ClusteringServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 31.03.2026.
//

import Foundation

// MARK: - ClusteringServiceProtocol

/// Defines the contract for a spatial clustering engine that groups
/// news items into map-ready clusters.
///
/// Implementations should be `Sendable` and actor-isolated to allow
/// off-main-thread clustering without data races.
///
/// ```swift
/// let clusters = try await clusteringService.cluster(
///   items: allNews,
///   in: visibleRegion,
///   zoomLevel: 12.0
/// )
/// ```
public protocol ClusteringServiceProtocol: Sendable {

  /// Groups news items into spatial clusters based on the visible
  /// map region and current zoom level.
  ///
  /// Higher zoom levels produce more, smaller clusters (items spread out).
  /// Lower zoom levels produce fewer, larger clusters (items merge).
  ///
  /// - Parameters:
  ///   - items: The full set of news items to cluster.
  ///   - region: The visible map region to constrain clustering.
  ///   - zoomLevel: The current zoom level (0–20, decimal).
  ///     Higher values = more zoomed in.
  /// - Returns: An array of ``NewsCluster``s covering the visible region.
  /// - Throws: ``NerveError`` if the clustering engine encounters an internal
  ///   error (e.g., out-of-memory or malformed input data).
  func cluster(
    items: [NewsItem],
    in region: GeoRegion,
    zoomLevel: Double
  ) async throws -> [NewsCluster]
}
