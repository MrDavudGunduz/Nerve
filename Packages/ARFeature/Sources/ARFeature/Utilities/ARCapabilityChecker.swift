//
//  ARCapabilityChecker.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Foundation
import OSLog

#if canImport(ARKit) && !os(macOS)
  import ARKit
#endif

// MARK: - ARCapabilityChecker

/// Determines which AR/spatial capabilities are available on the current device.
///
/// This is the **single source of truth** for feature gating:
/// - On **iOS/iPadOS:** checks `ARWorldTrackingConfiguration.isSupported`.
/// - On **visionOS:** spatial computing is always supported.
/// - On **macOS:** AR is not supported; falls back to SceneKit 3D viewer.
///
/// ## Thread Safety
///
/// All methods are synchronous reads of OS capability flags and are safe
/// to call from any context. The struct is `Sendable` by value semantics.
///
/// ## Usage
///
/// ```swift
/// let checker = ARCapabilityChecker()
/// if checker.supportsWorldTracking {
///   // Show RealityKit AR view
/// } else {
///   // Show SceneKit model viewer fallback
/// }
/// ```
public struct ARCapabilityChecker: Sendable {

  // MARK: - Logging

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ARCapabilityChecker"
  )

  // MARK: - Init

  public init() {}

  // MARK: - Capability Properties

  /// `true` if the device supports ARKit world tracking (plane detection).
  ///
  /// This is `false` on macOS and the iOS Simulator (no camera hardware).
  public var supportsWorldTracking: Bool {
    #if os(iOS)
      return ARWorldTrackingConfiguration.isSupported
    #else
      return false
    #endif
  }

  /// `true` if the device supports visionOS spatial computing.
  public var supportsSpatialComputing: Bool {
    #if os(visionOS)
      return true
    #else
      return false
    #endif
  }

  /// `true` if the device supports RealityKit rendering.
  ///
  /// RealityKit is available on iOS 13+ and visionOS, but **not** on macOS
  /// for camera-based AR. On macOS, we use SceneKit for 3D model viewing.
  public var supportsRealityKit: Bool {
    #if canImport(RealityKit) && !os(macOS)
      return true
    #else
      return false
    #endif
  }

  /// `true` if any form of 3D model display is available.
  ///
  /// This is always `true` because SceneKit is available on all Apple platforms.
  /// Used to determine if the AR button should be shown at all.
  public var supports3DModelViewing: Bool {
    true
  }

  /// The recommended viewer mode for the current device.
  public var recommendedViewerMode: ARViewerMode {
    if supportsSpatialComputing {
      return .spatial
    } else if supportsWorldTracking {
      return .augmentedReality
    } else {
      return .modelViewer
    }
  }
}

// MARK: - ARViewerMode

/// The rendering strategy for 3D content, determined by device capabilities.
///
/// Used by ``ARNewsViewModel`` to select the appropriate view hierarchy.
public enum ARViewerMode: String, Sendable, Codable {

  /// Full AR with camera feed and plane detection (iOS with ARKit).
  case augmentedReality

  /// Spatial computing with volumetric windows (visionOS).
  case spatial

  /// 3D model viewer without camera (macOS, Simulator, non-AR iOS).
  case modelViewer
}
