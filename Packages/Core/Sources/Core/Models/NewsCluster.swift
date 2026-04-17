//
//  NewsCluster.swift
//  Core
//
//  Created by Davud Gunduz on 31.03.2026.
//

import CryptoKit
import Foundation

// MARK: - NewsCluster

/// A spatial cluster of one or more news items for map rendering.
///
/// Produced by the clustering engine each time the visible map region
/// or zoom level changes. Consumers should treat this as an immutable
/// snapshot — a new array of clusters is generated on every re-cluster.
///
/// ```swift
/// let clusters = await clusterer.cluster(
///   items: newsItems,
///   in: visibleRegion,
///   zoomLevel: currentZoom
/// )
/// for cluster in clusters where cluster.isCluster {
///   print("\(cluster.count) items near \(cluster.center)")
/// }
/// ```
public struct NewsCluster: Sendable, Identifiable, Hashable {

  // MARK: - Properties

  /// Stable identifier derived from member item IDs.
  public let id: String

  /// The geographic center of this cluster (weighted centroid).
  public let center: GeoCoordinate

  /// The news items grouped into this cluster.
  public let items: [NewsItem]

  /// The publication date of the most recent item.
  public let latestDate: Date

  // MARK: - Computed

  /// The number of news items in this cluster.
  public var count: Int { items.count }

  /// Whether this cluster contains more than one item.
  public var isCluster: Bool { items.count > 1 }

  /// The most frequently occurring category among member items.
  ///
  /// When two or more categories share the highest count, the one with
  /// the alphabetically smallest `rawValue` wins — guaranteeing a
  /// deterministic result regardless of dictionary iteration order.
  public var dominantCategory: NewsCategory {
    let counts = Dictionary(grouping: items, by: \.category)
      .mapValues(\.count)
    return counts.max(by: { lhs, rhs in
      lhs.value == rhs.value
        ? lhs.key.rawValue > rhs.key.rawValue
        : lhs.value < rhs.value
    })?.key ?? .other
  }

  /// The headline of the item geographically closest to the cluster centroid.
  ///
  /// For single-item clusters this is the only item's headline.
  /// For multi-item clusters, this picks the most "representative" story —
  /// the one physically nearest the group's geographic centre of mass.
  public var representativeHeadline: String {
    items
      .min(by: { distanceToCenter($0) < distanceToCenter($1) })
      .map(\.headline) ?? ""
  }

  /// Squared Euclidean distance from an item's coordinate to the cluster centre.
  ///
  /// Squared distance avoids a `sqrt` call — sufficient for comparison purposes.
  private func distanceToCenter(_ item: NewsItem) -> Double {
    let dLat = item.coordinate.latitude - center.latitude
    let dLon = item.coordinate.longitude - center.longitude
    return dLat * dLat + dLon * dLon
  }

  /// Average credibility label across analyzed items, if any.
  public var averageCredibilityLabel: CredibilityLabel? {
    let scores = items.compactMap(\.analysis?.clickbaitScore)
    guard !scores.isEmpty else { return nil }
    let average = scores.reduce(0, +) / Double(scores.count)
    return HeadlineAnalysis.credibilityLabel(for: average)
  }

  // MARK: - Init

  /// Creates a cluster from a non-empty array of news items.
  ///
  /// The center is computed as the geographic centroid of all items.
  ///
  /// - Parameter items: One or more `NewsItem`s to group.
  ///   Must not be empty.
  /// - Returns: `nil` if `items` is empty or centroid is invalid.
  public init?(items: [NewsItem]) {
    guard !items.isEmpty else { return nil }

    let latSum = items.reduce(0.0) { $0 + $1.coordinate.latitude }
    let lonSum = items.reduce(0.0) { $0 + $1.coordinate.longitude }
    let count = Double(items.count)

    guard
      let centroid = GeoCoordinate(
        latitude: latSum / count,
        longitude: lonSum / count
      )
    else { return nil }

    // Deterministic, cross-process-stable ID derived from the SHA-256 digest
    // of the sorted, comma-joined member IDs.
    //
    // Why SHA-256 instead of Swift's Hasher:
    //   • Hasher uses per-process random seeding (Swift 4.2+), making its
    //     output change across app launches.
    //   • If a cluster ID ever reaches NavigationPath, state restoration,
    //     or a persistence layer, a Hasher-based ID would silently break it.
    //   • CryptoKit.SHA256 is a system framework — no extra SPM dependency.
    let sortedIDs = items.map(\.id).sorted().joined(separator: ",")
    let digest = SHA256.hash(data: Data(sortedIDs.utf8))
    self.id = digest.compactMap { String(format: "%02x", $0) }.joined()

    self.center = centroid
    self.items = items
    self.latestDate = items.map(\.publishedAt).max() ?? Date.distantPast
  }
}

// Note: HeadlineAnalysis.credibilityLabel(for:) lives in HeadlineAnalysis.swift
// and is the single source of truth for threshold logic.
