//
//  NewsServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for fetching news content from a remote or local source.
///
/// Concrete implementations live in `NetworkLayer` (API client) and
/// `StorageLayer` (cached data). The UI layer consumes this protocol
/// through the ``DependencyContainer``.
public protocol NewsServiceProtocol: Sendable {

  /// Fetches news items within the given geographic region.
  ///
  /// - Parameter region: The area to scope the query to.
  /// - Returns: An array of ``NewsItem`` instances (may be empty).
  /// - Throws: ``NerveError/network(message:context:)`` on network failure.
  func fetchNews(for region: GeoRegion) async throws -> [NewsItem]

  /// Fetches the full details of a single news item.
  ///
  /// - Parameter id: The unique identifier of the news item.
  /// - Returns: The matching ``NewsItem``.
  /// - Throws: ``NerveError/network(message:context:)`` if the item is not found
  ///   or the request fails.
  func fetchNewsDetail(id: String) async throws -> NewsItem
}
