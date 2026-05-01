//
//  ARNewsConfiguration.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Foundation

// MARK: - ARNewsConfiguration

/// Configuration constants and tuning parameters for the AR experience.
///
/// Centralizes all magic numbers, thresholds, and dimension values
/// used across the AR pipeline. Modifying these values adjusts the
/// AR experience without touching view or entity code.
///
/// ## Design Decision
///
/// `ARNewsConfiguration` is intentionally a `struct` with static
/// properties rather than an injectable service. These values are
/// compile-time constants that do not vary per user, device, or
/// environment — dependency injection would add unnecessary indirection.
public struct ARNewsConfiguration: Sendable {

  // MARK: - Model Placement

  /// Default distance (in meters) to place a model in front of the camera.
  ///
  /// Used when plane detection has not yet found a surface.
  public static let defaultModelDistance: Float = 0.5

  /// Default Y-axis offset (in meters) for models placed on a surface.
  public static let surfacePlacementOffset: Float = 0.0

  /// Maximum allowed scale factor for pinch-to-scale gestures.
  public static let maxScale: Float = 3.0

  /// Minimum allowed scale factor for pinch-to-scale gestures.
  public static let minScale: Float = 0.1

  // MARK: - Animation

  /// Duration (in seconds) for the model entrance animation.
  public static let entranceAnimationDuration: TimeInterval = 0.6

  /// Duration (in seconds) for the model exit animation.
  public static let exitAnimationDuration: TimeInterval = 0.3

  /// Spring damping ratio for placement animations.
  public static let springDampingRatio: Float = 0.7

  // MARK: - Overlay Card

  /// Offset (in meters) above the model where the info card hovers.
  public static let overlayCardYOffset: Float = 0.15

  /// Maximum width of the overlay card in points.
  public static let overlayCardMaxWidth: CGFloat = 320

  // MARK: - visionOS Volumetric

  /// Default volumetric window size in meters (width, height, depth).
  public static let volumetricWindowSize: SIMD3<Float> = [0.5, 0.5, 0.5]

  /// Scale factor for models inside volumetric windows.
  public static let volumetricModelScale: Float = 0.3

  // MARK: - Asset Cache

  /// Maximum number of USDZ models to keep in the disk cache.
  public static let maxCachedModels: Int = 10

  /// Maximum total cache size in bytes (50 MB).
  public static let maxCacheSizeBytes: Int = 50 * 1_024 * 1_024

  /// Cache directory name within the app's caches folder.
  public static let cacheDirectoryName = "ARModelCache"

  // MARK: - Placeholder

  /// Size of the placeholder loading entity (in meters).
  public static let placeholderSize: Float = 0.1

  /// Rotation speed of the placeholder (radians per second).
  public static let placeholderRotationSpeed: Float = 1.5
}
