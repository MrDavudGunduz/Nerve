//
//  URLSessionImageService.swift
//  NetworkLayer
//
//  Created by Davud Gunduz on 02.05.2026.
//

import Core
import CryptoKit
import Foundation
import OSLog

// MARK: - URLSessionImageService

/// Production implementation of ``ImageServiceProtocol`` using `URLSession`
/// with a two-tier (memory + disk) caching strategy.
///
/// ## Architecture
///
/// ```
/// loadImage(url)
///   ├── L1: In-memory NSCache → instant return
///   ├── L2: Disk cache (Caches dir) → fast return + promote to L1
///   └── L3: URLSession download → store in L1 + L2
/// ```
///
/// ## Memory Management
///
/// - **L1 (Memory):** `NSCache` with configurable byte limit. Automatically
///   evicts entries under memory pressure — no manual purging needed.
/// - **L2 (Disk):** Files stored in the app's `Caches` directory. The OS
///   may reclaim this space when storage is low.
///
/// ## Concurrency
///
/// `URLSessionImageService` is an **actor** to serialize cache reads/writes
/// and prevent duplicate downloads of the same URL.
///
/// ## Usage
///
/// ```swift
/// let imageService = URLSessionImageService(cacheSizeMB: 100)
/// let data = try await imageService.loadImage(from: thumbnailURL)
/// let image = UIImage(data: data)
/// ```
public actor URLSessionImageService: ImageServiceProtocol {

  // MARK: - Dependencies

  private let session: URLSession
  private let memoryCache: NSCache<NSString, NSData>
  private let diskCacheDirectory: URL

  /// URLs currently being downloaded — prevents duplicate concurrent requests.
  private var inflightRequests: [URL: Task<Data, any Error>] = [:]

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.NetworkLayer",
    category: "URLSessionImageService"
  )

  // MARK: - Init

  /// Creates an image service with configurable cache sizes.
  ///
  /// - Parameters:
  ///   - cacheSizeMB: Maximum memory cache size in megabytes (default: 100).
  ///   - session: Optional custom URLSession (default: shared).
  public init(
    cacheSizeMB: Int = 100,
    session: URLSession = .shared
  ) {
    self.session = session

    // ── L1: Memory Cache ──
    let cache = NSCache<NSString, NSData>()
    cache.totalCostLimit = cacheSizeMB * 1_024 * 1_024
    cache.countLimit = 500  // Max cached image entries.
    self.memoryCache = cache

    // ── L2: Disk Cache ──
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    self.diskCacheDirectory = cacheDir.appendingPathComponent("NerveImageCache", isDirectory: true)

    // Ensure cache directory exists.
    try? FileManager.default.createDirectory(
      at: diskCacheDirectory,
      withIntermediateDirectories: true
    )
  }

  // MARK: - ImageServiceProtocol

  /// Loads image data from the given URL using a two-tier cache.
  ///
  /// 1. **L1 (Memory):** Returns immediately if cached.
  /// 2. **L2 (Disk):** Loads from disk, promotes to L1, and returns.
  /// 3. **L3 (Network):** Downloads, stores in both caches, and returns.
  ///
  /// Duplicate concurrent requests for the same URL are coalesced —
  /// only one download is dispatched, and all waiters receive the same result.
  ///
  /// - Parameter url: The remote URL of the image.
  /// - Returns: The raw image data.
  /// - Throws: ``NerveError/network(message:context:)`` on download failure.
  public func loadImage(from url: URL) async throws -> Data {
    let cacheKey = Self.cacheKey(for: url)

    // ── L1: Memory Cache ──
    if let cached = memoryCache.object(forKey: cacheKey as NSString) {
      Self.logger.debug("L1 cache hit: \(url.lastPathComponent)")
      return cached as Data
    }

    // ── L2: Disk Cache ──
    let diskURL = diskCacheURL(for: cacheKey)
    if let diskData = try? Data(contentsOf: diskURL) {
      // Promote to L1.
      memoryCache.setObject(diskData as NSData, forKey: cacheKey as NSString, cost: diskData.count)
      Self.logger.debug("L2 cache hit: \(url.lastPathComponent)")
      return diskData
    }

    // ── Coalesce Duplicate Requests ──
    if let inflightTask = inflightRequests[url] {
      Self.logger.debug("Coalescing duplicate request: \(url.lastPathComponent)")
      return try await inflightTask.value
    }

    // ── L3: Network Download ──
    let downloadTask = Task<Data, any Error> { [session] in
      let data = try await RetryPolicy.execute(
        maxAttempts: 2,
        baseDelay: 0.5,
        shouldRetry: { error in
          if let urlError = error as? URLError {
            return urlError.code == .timedOut || urlError.code == .networkConnectionLost
          }
          return false
        }
      ) {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode)
        else {
          throw NerveError.network(
            message:
              "Image download failed: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
          )
        }

        guard !data.isEmpty else {
          throw NerveError.network(message: "Image download returned empty data.")
        }

        return data
      }

      Self.logger.info("Downloaded image: \(url.lastPathComponent) (\(data.count) bytes)")
      return data
    }

    inflightRequests[url] = downloadTask

    do {
      let data = try await downloadTask.value

      // Store in both caches.
      memoryCache.setObject(data as NSData, forKey: cacheKey as NSString, cost: data.count)
      try? data.write(to: diskURL, options: .atomic)

      inflightRequests[url] = nil
      return data

    } catch {
      inflightRequests[url] = nil
      throw NerveError.network(
        message: "Image download failed: \(error.localizedDescription)",
        context: ErrorContext(underlyingError: error)
      )
    }
  }

  /// Removes all entries from both memory and disk caches.
  public func clearCache() async {
    memoryCache.removeAllObjects()

    do {
      let files = try FileManager.default.contentsOfDirectory(
        at: diskCacheDirectory,
        includingPropertiesForKeys: nil
      )
      for file in files {
        try? FileManager.default.removeItem(at: file)
      }
      Self.logger.info("Image cache cleared: \(files.count) files removed.")
    } catch {
      Self.logger.warning("Failed to clear disk cache: \(error.localizedDescription)")
    }
  }

  // MARK: - Cache Key

  /// Generates a stable cache key from a URL using SHA-256.
  ///
  /// Using a hash avoids filesystem issues with long URLs or special characters.
  private static func cacheKey(for url: URL) -> String {
    let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  /// Returns the disk cache file URL for a given cache key.
  private func diskCacheURL(for key: String) -> URL {
    diskCacheDirectory.appendingPathComponent(key)
  }
}
