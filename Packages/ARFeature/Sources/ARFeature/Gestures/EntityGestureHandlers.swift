//
//  EntityGestureHandlers.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(RealityKit)
  import Foundation
  import RealityKit
  import SwiftUI

  // MARK: - EntityGestureState

  /// Accumulated state for multi-gesture entity manipulation.
  ///
  /// Tracks the baseline transform before a gesture sequence begins
  /// so that incremental gesture values can be applied relative to
  /// the starting orientation and scale.
  @MainActor
  public struct EntityGestureState {

    /// The entity's scale at the start of a pinch gesture.
    public var initialScale: SIMD3<Float> = [1, 1, 1]

    /// The entity's rotation at the start of a rotation gesture.
    public var initialRotation: simd_quatf = simd_quatf(
      angle: 0,
      axis: [0, 1, 0]
    )

    /// The entity's position at the start of a drag gesture.
    public var initialPosition: SIMD3<Float> = .zero

    /// Whether this is the first gesture event in a sequence.
    ///
    /// Used to trigger one-time haptic feedback at the start of an
    /// interaction without firing on every `.onChanged` callback.
    public var isFirstEvent: Bool = true

    /// Creates a gesture state snapshot from the current entity transform.
    public init() {}

    /// Captures the current transform of an entity as the baseline.
    public mutating func captureBaseline(from entity: Entity) {
      initialScale = entity.scale
      initialRotation = entity.orientation
      initialPosition = entity.position
      isFirstEvent = true
    }
  }

  // MARK: - EntityGestureHandlers

  /// Provides reusable gesture handling logic for 3D entities.
  ///
  /// Encapsulates the math for translating SwiftUI gesture values
  /// into RealityKit transform mutations. Used by both the AR view
  /// and the volumetric view.
  ///
  /// ## Supported Gestures
  ///
  /// - **Drag:** Repositions the entity on the XZ plane.
  /// - **Magnify (Pinch):** Scales the entity uniformly.
  /// - **Rotate:** Rotates the entity around the Y axis.
  ///
  /// ## Haptic Feedback
  ///
  /// Each gesture type triggers a light haptic on first contact
  /// via ``ARHapticEngine``. Scale and rotation gestures also
  /// trigger limit-reached haptics when clamped to bounds.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // In a RealityView gesture modifier:
  /// .gesture(
  ///   DragGesture()
  ///     .targetedToAnyEntity()
  ///     .onChanged { value in
  ///       EntityGestureHandlers.handleDrag(value, state: &gestureState)
  ///     }
  /// )
  /// ```
  @MainActor
  public enum EntityGestureHandlers {

    /// Handles a drag gesture to reposition an entity.
    ///
    /// Converts the 2D drag translation into a 3D position offset
    /// on the XZ plane (horizontal movement). Y position is preserved.
    ///
    /// - Parameters:
    ///   - translation: The 2D translation from the gesture.
    ///   - entity: The entity to reposition.
    ///   - state: The gesture state tracking baseline transform.
    ///   - sensitivity: Movement sensitivity multiplier (default: 0.001).
    public static func handleDrag(
      translation: CGSize,
      on entity: Entity,
      state: inout EntityGestureState,
      sensitivity: Float = 0.001
    ) {
      // Haptic on first contact.
      triggerStartHapticIfNeeded(&state)

      let deltaX = Float(translation.width) * sensitivity
      let deltaZ = Float(translation.height) * sensitivity

      entity.position = SIMD3<Float>(
        state.initialPosition.x + deltaX,
        state.initialPosition.y,
        state.initialPosition.z + deltaZ
      )
    }

    /// Handles a magnification (pinch) gesture to scale an entity.
    ///
    /// Applies uniform scaling clamped to configured min/max bounds.
    /// Triggers a limit-reached haptic when the scale hits a boundary.
    ///
    /// - Parameters:
    ///   - magnification: The magnification factor from the gesture (1.0 = no change).
    ///   - entity: The entity to scale.
    ///   - state: The gesture state tracking baseline transform.
    public static func handleScale(
      magnification: CGFloat,
      on entity: Entity,
      state: inout EntityGestureState
    ) {
      // Haptic on first contact.
      triggerStartHapticIfNeeded(&state)

      let scaleFactor = Float(magnification)
      let newScale = state.initialScale * scaleFactor

      // Clamp each axis to configured bounds.
      let minScale = ARNewsConfiguration.minScale
      let maxScale = ARNewsConfiguration.maxScale

      let clamped = SIMD3<Float>(
        min(max(newScale.x, minScale), maxScale),
        min(max(newScale.y, minScale), maxScale),
        min(max(newScale.z, minScale), maxScale)
      )

      // Detect if any axis hit a limit.
      let hitLimit =
        clamped.x != newScale.x || clamped.y != newScale.y || clamped.z != newScale.z

      entity.scale = clamped

      #if os(iOS)
        if hitLimit {
          ARHapticEngine.playLimitReached()
        }
      #endif
    }

    /// Handles a rotation gesture to rotate an entity around the Y axis.
    ///
    /// - Parameters:
    ///   - angle: The rotation angle from the gesture.
    ///   - entity: The entity to rotate.
    ///   - state: The gesture state tracking baseline transform.
    public static func handleRotation(
      angle: Angle,
      on entity: Entity,
      state: inout EntityGestureState
    ) {
      // Haptic on first contact.
      triggerStartHapticIfNeeded(&state)

      let rotationDelta = simd_quatf(
        angle: Float(angle.radians),
        axis: [0, 1, 0]
      )
      entity.orientation = state.initialRotation * rotationDelta
    }

    // MARK: - Private

    /// Triggers a start haptic only on the first event of a gesture sequence.
    private static func triggerStartHapticIfNeeded(_ state: inout EntityGestureState) {
      guard state.isFirstEvent else { return }
      state.isFirstEvent = false

      #if os(iOS)
        ARHapticEngine.playGestureStart()
      #endif
    }
  }
#endif
