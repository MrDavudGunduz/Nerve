//
//  PlaceholderNewsService.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation
import OSLog

// MARK: - PlaceholderNewsService

/// A no-op ``NewsServiceProtocol`` implementation that returns empty results.
///
/// Used as the default registration in ``AppBootstrapper`` until the
/// production `NetworkNewsService` is implemented. Each method logs
/// a warning so developers are aware the placeholder is active.
///
/// ## Replacing This Placeholder
///
/// When the real API client is ready:
///
/// ```swift
/// await container.register(NewsServiceProtocol.self, lifetime: .singleton) {
///   NetworkNewsService(baseURL: AppConfig.apiBaseURL)
/// }
/// ```
public struct PlaceholderNewsService: NewsServiceProtocol {

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.NetworkLayer",
    category: "PlaceholderNewsService"
  )

  public init() {}

  public func fetchNews(for region: GeoRegion) async throws -> [NewsItem] {
    Self.logger.warning(
      "PlaceholderNewsService.fetchNews called — no data returned. Implement NetworkNewsService."
    )
    return []
  }

  public func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(
      message:
        "PlaceholderNewsService does not support fetchNewsDetail(id:). Implement NetworkNewsService."
    )
  }
}
