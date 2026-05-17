//
//  ARTrackingState.swift
//  ARFeature
//
//  Created by Davud Gunduz on 16.05.2026.
//

import Foundation

// MARK: - ARTrackingQuality

/// Represents the quality of ARKit's world tracking.
///
/// Used by the UI layer to display contextual guidance (e.g.,
/// "Move your device to improve tracking") and to gate model
/// placement until tracking reaches an acceptable quality.
///
/// ## Mapping
///
/// | ARKit State                                 | Quality        |
/// |---------------------------------------------|----------------|
/// | `.normal`                                   | `.good`        |
/// | `.limited(.insufficientFeatures)`           | `.limited`     |
/// | `.limited(.excessiveMotion)`                | `.limited`     |
/// | `.limited(.initializing)`                   | `.initializing`|
/// | `.notAvailable`                             | `.unavailable` |
public enum ARTrackingQuality: String, Sendable, Equatable {

  /// Tracking is fully operational with high confidence.
  case good

  /// Tracking is degraded — user should improve conditions.
  case limited

  /// ARKit is still initializing — scanning for features.
  case initializing

  /// Tracking is not available on this device or session.
  case unavailable

  /// A user-facing message describing the tracking state.
  public var userMessage: String {
    switch self {
    case .good:
      return "Tracking is ready. Tap a surface to place the model."
    case .limited:
      return "Move your device slowly to improve tracking."
    case .initializing:
      return "Scanning environment…"
    case .unavailable:
      return "AR tracking is not available."
    }
  }

  /// The SF Symbol name representing the tracking quality.
  public var iconName: String {
    switch self {
    case .good: return "checkmark.circle.fill"
    case .limited: return "exclamationmark.triangle.fill"
    case .initializing: return "circle.dotted"
    case .unavailable: return "xmark.circle.fill"
    }
  }
}

// MARK: - ARPlacementState

/// Represents the entity placement lifecycle in an AR session.
///
/// Drives the coaching → scanning → placed state machine
/// in ``ARNewsViewModel``.
public enum ARPlacementState: Sendable, Equatable {

  /// Coaching overlay is visible, guiding the user to scan surfaces.
  case coaching

  /// A horizontal surface has been detected; waiting for user tap or auto-placement.
  case surfaceDetected

  /// The model has been placed on a surface and is interactive.
  case placed

  /// The model is performing its entrance animation.
  case animatingEntrance

  /// Whether the model is in a final, interactive state.
  public var isInteractive: Bool {
    self == .placed
  }
}
