//
//  ARServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Foundation

// MARK: - ARModelAsset

/// Metadata describing a 3D model asset associated with a news story.
///
/// `ARModelAsset` is a lightweight descriptor that identifies which USDZ model
/// to load, its display name, and an optional remote URL for on-demand download.
/// It does **not** hold the model data itself — that responsibility belongs to
/// the asset-loading layer in `ARFeature`.
///
/// ```swift
/// let asset = ARModelAsset(
///   name: "tech_gadget",
///   displayName: "AR Gadget Preview",
///   remoteURL: URL(string: "https://cdn.nerve.app/models/tech_gadget.usdz")
/// )
/// ```
public struct ARModelAsset: Sendable, Codable, Hashable {

  /// The file name of the USDZ model (without extension).
  ///
  /// Used as the key for both bundle lookup and cache storage.
  public let name: String

  /// A human-readable label shown in the UI while the model is loading.
  public let displayName: String

  /// Optional remote URL to download the model if not bundled.
  public let remoteURL: URL?

  /// Creates a new model asset descriptor.
  ///
  /// - Parameters:
  ///   - name: The USDZ file name (without `.usdz` extension).
  ///   - displayName: A user-facing label for the model.
  ///   - remoteURL: An optional URL for on-demand download.
  public init(name: String, displayName: String, remoteURL: URL? = nil) {
    self.name = name
    self.displayName = displayName
    self.remoteURL = remoteURL
  }
}

// MARK: - ARServiceProtocol

/// Abstraction for AR/3D model management and capability checking.
///
/// Concrete implementations live in `ARFeature`. The UI layer
/// resolves this protocol via ``DependencyContainer`` to determine
/// whether AR experiences are available on the current device.
///
/// ## Responsibilities
///
/// 1. **Capability detection** — reports whether the device supports
///    camera-based AR (ARKit) or spatial computing (visionOS).
/// 2. **Model eligibility** — determines whether a ``NewsItem``
///    has an associated 3D model for AR display.
/// 3. **Asset caching** — manages download, storage, and eviction
///    of USDZ model files.
///
/// ## Thread Safety
///
/// Implementations must be `Sendable`. Actor isolation is recommended
/// for mutable cache state.
public protocol ARServiceProtocol: Sendable {

  /// Returns `true` if the current device supports AR experiences.
  ///
  /// On iOS, this checks for ARKit plane-detection capability.
  /// On visionOS, this always returns `true`.
  /// On macOS, this returns `false` (SceneKit fallback is used instead).
  func isARSupported() async -> Bool

  /// Returns `true` if the current device supports visionOS spatial UI.
  func isSpatialComputingSupported() async -> Bool

  /// Returns the ``ARModelAsset`` for a news item, if one is available.
  ///
  /// Not all news stories have associated 3D models. This method
  /// checks the item's category and metadata to determine eligibility.
  ///
  /// - Parameter newsItem: The news item to check.
  /// - Returns: The model asset descriptor, or `nil` if no model exists.
  func modelAsset(for newsItem: NewsItem) async -> ARModelAsset?

  /// Preloads and caches a model asset for faster display.
  ///
  /// Call this when a user is likely to open the AR viewer
  /// (e.g., when they scroll to an AR-eligible story).
  ///
  /// - Parameter asset: The asset to preload.
  /// - Throws: ``NerveError/network(message:context:)`` if download fails.
  func preloadAsset(_ asset: ARModelAsset) async throws

  /// Removes all cached model assets from disk.
  ///
  /// Frees storage space. Cached models will be re-downloaded on next access.
  func clearAssetCache() async
}
