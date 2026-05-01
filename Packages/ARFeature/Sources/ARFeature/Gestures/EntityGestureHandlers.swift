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

    /// Creates a gesture state snapshot from the current entity transform.
    public init() {}

    /// Captures the current transform of an entity as the baseline.
    public mutating func captureBaseline(from entity: Entity) {
      initialScale = entity.scale
      initialRotation = entity.orientation
      initialPosition = entity.position
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
      state: EntityGestureState,
      sensitivity: Float = 0.001
    ) {
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
    ///
    /// - Parameters:
    ///   - magnification: The magnification factor from the gesture (1.0 = no change).
    ///   - entity: The entity to scale.
    ///   - state: The gesture state tracking baseline transform.
    public static func handleScale(
      magnification: CGFloat,
      on entity: Entity,
      state: EntityGestureState
    ) {
      let scaleFactor = Float(magnification)
      let newScale = state.initialScale * scaleFactor

      // Clamp each axis to configured bounds.
      let clamped = SIMD3<Float>(
        min(max(newScale.x, ARNewsConfiguration.minScale), ARNewsConfiguration.maxScale),
        min(max(newScale.y, ARNewsConfiguration.minScale), ARNewsConfiguration.maxScale),
        min(max(newScale.z, ARNewsConfiguration.minScale), ARNewsConfiguration.maxScale)
      )

      entity.scale = clamped
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
      state: EntityGestureState
    ) {
      let rotationDelta = simd_quatf(
        angle: Float(angle.radians),
        axis: [0, 1, 0]
      )
      entity.orientation = state.initialRotation * rotationDelta
    }
  }
#endif
