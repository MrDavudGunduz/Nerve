//
//  ImageServiceProtocol.swift
//  Core
//
//  Created by Davud Gunduz on 26.03.2026.
//

import Foundation

/// Abstraction for loading and caching images from remote URLs.
///
/// Concrete implementations live in `NetworkLayer` and provide
/// in-memory and disk caching of downloaded image data.
public protocol ImageServiceProtocol: Sendable {

  /// Downloads or retrieves from cache the image at the given URL.
  ///
  /// - Parameter url: The remote URL of the image.
  /// - Returns: The raw image data.
  func loadImage(from url: URL) async throws -> Data

  /// Removes all entries from the image cache.
  func clearCache() async
}
