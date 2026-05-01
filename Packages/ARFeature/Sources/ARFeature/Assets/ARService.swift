//
//  ARService.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation
import OSLog

// MARK: - ARService

/// Concrete implementation of ``ARServiceProtocol``.
///
/// Bridges the ``ARCapabilityChecker`` and ``ARAssetManager`` into a
/// single injectable service that the app layer and UI can consume
/// via the ``DependencyContainer``.
///
/// ## Thread Safety
///
/// Implemented as a Swift `actor` to serialize asset manager interactions.
/// Capability checks are synchronous value reads and do not require
/// actor isolation, but are wrapped in `async` to satisfy the protocol.
public actor ARService: ARServiceProtocol {

  // MARK: - Dependencies

  private let capabilityChecker: ARCapabilityChecker
  private let assetManager: ARAssetManager

  // MARK: - Logging

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ARService"
  )

  // MARK: - Init

  /// Creates a new AR service.
  ///
  /// - Parameters:
  ///   - capabilityChecker: Override for testing.
  ///   - assetManager: Override for testing with custom cache paths.
  public init(
    capabilityChecker: ARCapabilityChecker = ARCapabilityChecker(),
    assetManager: ARAssetManager = ARAssetManager()
  ) {
    self.capabilityChecker = capabilityChecker
    self.assetManager = assetManager
  }

  // MARK: - Capability Detection

  public func isARSupported() async -> Bool {
    capabilityChecker.supportsWorldTracking
  }

  public func isSpatialComputingSupported() async -> Bool {
    capabilityChecker.supportsSpatialComputing
  }

  // MARK: - Model Resolution

  public func modelAsset(for newsItem: NewsItem) async -> ARModelAsset? {
    guard newsItem.isARCapable, let modelName = newsItem.arModelName else {
      return nil
    }

    return ARModelAsset(
      name: modelName,
      displayName: "\(newsItem.headline) — AR Preview"
    )
  }

  // MARK: - Asset Management

  public func preloadAsset(_ asset: ARModelAsset) async throws {
    Self.logger.info("Preloading asset '\(asset.name)'…")
    try await assetManager.downloadAndCache(asset)
  }

  public func clearAssetCache() async {
    Self.logger.info("Clearing AR asset cache…")
    await assetManager.clearCache()
  }
}
