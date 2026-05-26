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

  // MARK: - Coaching Overlay

  /// Whether to show the ARKit coaching overlay on session start.
  ///
  /// When `true`, a semi-transparent instructional overlay guides the user
  /// to scan a horizontal surface before model placement.
  public static let showCoachingOverlay: Bool = true

  /// Maximum duration (seconds) to show coaching before auto-dismissing.
  ///
  /// Prevents the coaching overlay from blocking the experience indefinitely
  /// if the user is in a valid but challenging environment.
  public static let coachingTimeoutDuration: TimeInterval = 15.0

  /// Delay (seconds) before coaching overlay appears after session start.
  ///
  /// Gives ARKit a brief moment to initialize before showing guidance.
  public static let coachingAppearanceDelay: TimeInterval = 0.5

  // MARK: - Haptic Feedback

  /// Haptic intensity for entity placement on a surface (0.0 – 1.0).
  public static let placementHapticIntensity: Float = 0.8

  /// Haptic intensity for gesture interaction start (0.0 – 1.0).
  public static let gestureStartHapticIntensity: Float = 0.4

  /// Haptic intensity for scale/rotation limit reached (0.0 – 1.0).
  public static let limitReachedHapticIntensity: Float = 0.6

  // MARK: - Entrance Animation

  /// Scale factor at the start of the entrance animation.
  ///
  /// The model spawns at this scale and springs to 1.0.
  public static let entranceStartScale: Float = 0.01

  /// Y-axis offset (meters) for the drop-in entrance animation.
  ///
  /// The model drops from this offset above its target position.
  public static let entranceDropOffset: Float = 0.15

  /// Spring response (seconds) for the entrance animation.
  public static let entranceSpringResponse: Float = 0.5

  /// Spring damping fraction for the entrance animation.
  public static let entranceSpringDamping: Float = 0.7

  // MARK: - Tracking Quality

  /// Minimum number of feature points for "good" tracking quality.
  public static let goodTrackingFeaturePointThreshold: Int = 100

  /// Duration (seconds) of insufficient tracking before showing a warning.
  public static let trackingWarningDelay: TimeInterval = 3.0

  // MARK: - Spatial Map (Immersive Space)

  /// Scale factor to convert geographic degrees to scene meters.
  ///
  /// A value of 0.01 maps 1° of latitude/longitude to 0.01m in the scene.
  /// Adjust this to control annotation spread in the immersive map.
  public static let geoToSceneScale: Float = 0.01

  /// Height offset (meters) for floating annotation tags above the map surface.
  public static let annotationYOffset: Float = 0.18

  /// Base height of the map surface below the origin.
  public static let mapSurfaceY: Float = -0.3

  /// Width and depth of the map surface in meters.
  public static let mapSurfaceSize: Float = 2.5

  /// Radius of annotation marker spheres in meters.
  public static let annotationMarkerRadius: Float = 0.018

  /// Radius of the vertical connecting line cylinders.
  public static let annotationLineRadius: Float = 0.002

  /// Ambient light intensity for the immersive scene.
  public static let ambientLightIntensity: Float = 600

  // MARK: - Scene Transitions

  /// Delay (seconds) between closing one spatial scene and opening another.
  ///
  /// Gives visionOS enough time to complete the close animation
  /// before starting the open animation, preventing visual glitches.
  public static let interSceneTransitionDelay: TimeInterval = 0.4

  /// Duration (seconds) of the idle rotation pause after a gesture interaction.
  ///
  /// After the user finishes manipulating a volumetric model, idle rotation
  /// resumes after this interval.
  public static let idleRotationResumeDelay: TimeInterval = 2.0
}
