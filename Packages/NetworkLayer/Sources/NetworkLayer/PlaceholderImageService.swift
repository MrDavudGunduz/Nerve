//
//  PlaceholderImageService.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation
import OSLog

// MARK: - PlaceholderImageService

/// A no-op ``ImageServiceProtocol`` implementation that returns empty data.
///
/// Used as the default registration in ``AppBootstrapper`` until the
/// production `URLSessionImageService` is implemented. Each method logs
/// a warning so developers are aware the placeholder is active.
///
/// ## Replacing This Placeholder
///
/// When the real image service is ready:
///
/// ```swift
/// await container.register(ImageServiceProtocol.self, lifetime: .singleton) {
///   URLSessionImageService(cacheSizeMB: 100)
/// }
/// ```
public struct PlaceholderImageService: ImageServiceProtocol {

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.NetworkLayer",
    category: "PlaceholderImageService"
  )

  public init() {}

  public func loadImage(from url: URL) async throws -> Data {
    Self.logger.warning(
      "PlaceholderImageService.loadImage called — returning empty data. Implement URLSessionImageService."
    )
    return Data()
  }

  public func clearCache() async {
    // No-op for placeholder.
  }
}
