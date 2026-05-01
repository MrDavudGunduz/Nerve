//
//  ARAssetManager.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation
import OSLog

// MARK: - ARAssetManager

/// Manages the lifecycle of 3D model assets: discovery, caching, and eviction.
///
/// `ARAssetManager` provides a two-tier asset resolution strategy:
///
/// 1. **Bundle lookup** — checks if the USDZ file is shipped with the app.
/// 2. **Disk cache** — checks the local cache directory.
/// 3. **Remote download** — fetches from the CDN and persists to disk cache.
///
/// ## Thread Safety
///
/// Implemented as a Swift `actor` to serialize cache mutations.
/// Read-only operations (capability checks, path resolution) are safe
/// to call concurrently.
///
/// ## Cache Eviction
///
/// LRU eviction is triggered when the cache exceeds ``ARNewsConfiguration/maxCachedModels``
/// or ``ARNewsConfiguration/maxCacheSizeBytes``.
public actor ARAssetManager {

  // MARK: - Logging

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ARAssetManager"
  )

  // MARK: - State

  /// Tracks access timestamps for LRU eviction.
  private var accessLog: [String: Date] = [:]

  /// The URL of the on-disk cache directory.
  private let cacheDirectory: URL

  // MARK: - Init

  /// Creates a new asset manager with the specified cache directory.
  ///
  /// If `cacheDirectory` is `nil`, uses the system caches directory
  /// with ``ARNewsConfiguration/cacheDirectoryName``.
  ///
  /// - Parameter cacheDirectory: Custom cache directory for testing.
  public init(cacheDirectory: URL? = nil) {
    if let cacheDirectory {
      self.cacheDirectory = cacheDirectory
    } else {
      let systemCaches = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
      ).first!
      self.cacheDirectory = systemCaches.appendingPathComponent(
        ARNewsConfiguration.cacheDirectoryName,
        isDirectory: true
      )
    }

    // Ensure cache directory exists.
    try? FileManager.default.createDirectory(
      at: self.cacheDirectory,
      withIntermediateDirectories: true
    )
  }

  // MARK: - Asset Resolution

  /// Resolves the local file URL for a model asset.
  ///
  /// Checks the bundle first, then the disk cache.
  /// Returns `nil` if the asset is not available locally.
  ///
  /// - Parameter asset: The asset descriptor to resolve.
  /// - Returns: A file URL to the USDZ model, or `nil`.
  public func localURL(for asset: ARModelAsset) -> URL? {
    // 1. Check the app bundle.
    if let bundleURL = Bundle.main.url(
      forResource: asset.name,
      withExtension: "usdz"
    ) {
      recordAccess(for: asset.name)
      Self.logger.debug("Asset '\(asset.name)' found in bundle.")
      return bundleURL
    }

    // 2. Check the disk cache.
    let cachedURL = cacheFileURL(for: asset.name)
    if FileManager.default.fileExists(atPath: cachedURL.path) {
      recordAccess(for: asset.name)
      Self.logger.debug("Asset '\(asset.name)' found in disk cache.")
      return cachedURL
    }

    Self.logger.debug("Asset '\(asset.name)' not available locally.")
    return nil
  }

  /// Downloads and caches a remote model asset.
  ///
  /// If the asset already exists locally, this is a no-op.
  ///
  /// - Parameter asset: The asset to download.
  /// - Throws: ``NerveError/network(message:context:)`` if download fails.
  public func downloadAndCache(_ asset: ARModelAsset) async throws {
    // Skip if already cached.
    if localURL(for: asset) != nil { return }

    guard let remoteURL = asset.remoteURL else {
      Self.logger.warning(
        "Asset '\(asset.name)' has no remote URL and is not in bundle. Cannot download."
      )
      return
    }

    Self.logger.info("Downloading asset '\(asset.name)' from \(remoteURL.absoluteString)…")

    let (data, response) = try await URLSession.shared.data(from: remoteURL)

    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      throw NerveError.network(
        message: "Failed to download AR model '\(asset.name)': HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
      )
    }

    let destination = cacheFileURL(for: asset.name)
    try data.write(to: destination, options: .atomic)
    recordAccess(for: asset.name)

    Self.logger.info(
      "Asset '\(asset.name)' cached successfully (\(data.count) bytes)."
    )

    // Trigger eviction if needed.
    await evictIfNeeded()
  }

  /// Removes all cached model assets from disk.
  public func clearCache() {
    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: cacheDirectory,
        includingPropertiesForKeys: nil
      )
      for fileURL in contents {
        try FileManager.default.removeItem(at: fileURL)
      }
      accessLog.removeAll()
      Self.logger.info("AR asset cache cleared.")
    } catch {
      Self.logger.error(
        "Failed to clear AR asset cache: \(error.localizedDescription)"
      )
    }
  }

  /// Returns the total size of the disk cache in bytes.
  public func cacheSizeBytes() -> Int {
    guard
      let contents = try? FileManager.default.contentsOfDirectory(
        at: cacheDirectory,
        includingPropertiesForKeys: [.fileSizeKey]
      )
    else { return 0 }

    return contents.reduce(0) { total, url in
      let size =
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
      return total + size
    }
  }

  /// Returns the number of models currently in the disk cache.
  public func cachedModelCount() -> Int {
    let contents =
      try? FileManager.default.contentsOfDirectory(
        at: cacheDirectory,
        includingPropertiesForKeys: nil
      )
    return (contents ?? []).filter { $0.pathExtension == "usdz" }.count
  }

  // MARK: - Private Helpers

  private func cacheFileURL(for modelName: String) -> URL {
    cacheDirectory.appendingPathComponent("\(modelName).usdz")
  }

  private func recordAccess(for modelName: String) {
    accessLog[modelName] = Date()
  }

  /// Evicts least-recently-used assets if cache limits are exceeded.
  private func evictIfNeeded() async {
    let currentCount = cachedModelCount()
    let currentSize = cacheSizeBytes()

    guard
      currentCount > ARNewsConfiguration.maxCachedModels
        || currentSize > ARNewsConfiguration.maxCacheSizeBytes
    else { return }

    // Sort by last access time, oldest first.
    let sorted = accessLog.sorted { $0.value < $1.value }

    for (modelName, _) in sorted {
      let fileURL = cacheFileURL(for: modelName)
      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        accessLog.removeValue(forKey: modelName)
        continue
      }

      do {
        try FileManager.default.removeItem(at: fileURL)
        accessLog.removeValue(forKey: modelName)
        Self.logger.info("Evicted cached asset '\(modelName)'.")
      } catch {
        Self.logger.error(
          "Failed to evict '\(modelName)': \(error.localizedDescription)"
        )
      }

      // Re-check limits.
      if cachedModelCount() <= ARNewsConfiguration.maxCachedModels
        && cacheSizeBytes() <= ARNewsConfiguration.maxCacheSizeBytes
      {
        break
      }
    }
  }
}
