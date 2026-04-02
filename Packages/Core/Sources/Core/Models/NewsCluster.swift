//
//  NewsCluster.swift
//  Core
//
//  Created by Davud Gunduz on 31.03.2026.
//

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
  public var dominantCategory: NewsCategory {
    let counts = Dictionary(grouping: items, by: \.category)
      .mapValues(\.count)
    return counts.max(by: { $0.value < $1.value })?.key ?? .other
  }

  /// The headline of the item closest to the centroid, used as
  /// the representative headline for the cluster.
  public var representativeHeadline: String {
    items.first?.headline ?? ""
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

    // Deterministic ID from sorted member IDs.
    let sortedIDs = items.map(\.id).sorted()
    self.id = sortedIDs.joined(separator: "+")
    self.center = centroid
    self.items = items
    self.latestDate = items.map(\.publishedAt).max() ?? Date.distantPast
  }
}

// MARK: - HeadlineAnalysis Extension

extension HeadlineAnalysis {

  /// Computes the credibility label for a given clickbait score.
  ///
  /// This is extracted as a static helper so that `NewsCluster` can
  /// compute an average credibility without constructing a full
  /// `HeadlineAnalysis` instance.
  public static func credibilityLabel(for score: Double) -> CredibilityLabel {
    switch score {
    case ..<0.3: return .verified
    case 0.3..<0.7: return .caution
    default: return .clickbait
    }
  }
}
