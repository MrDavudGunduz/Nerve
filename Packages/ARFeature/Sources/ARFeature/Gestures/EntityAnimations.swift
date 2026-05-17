//
//  EntityAnimations.swift
//  ARFeature
//
//  Created by Davud Gunduz on 16.05.2026.
//

#if canImport(RealityKit)
  import Foundation
  import RealityKit

  // MARK: - EntityAnimations

  /// Reusable entity animations for the AR news viewer.
  ///
  /// Provides spring-based entrance, exit, and feedback animations
  /// that give the AR experience a polished, professional feel.
  ///
  /// ## Design
  ///
  /// All animations use `Transform` manipulation with `move(to:relativeTo:duration:)`
  /// for smooth interpolation. Parameters are sourced from ``ARNewsConfiguration``
  /// so tuning is centralized.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // After loading and attaching a model entity:
  /// await EntityAnimations.playEntrance(on: entity, targetY: 0.0)
  /// ```
  @MainActor
  public enum EntityAnimations {

    // MARK: - Entrance Animation

    /// Plays a spring-based drop-in and scale-up entrance animation.
    ///
    /// The entity starts at ``ARNewsConfiguration/entranceStartScale``
    /// and ``ARNewsConfiguration/entranceDropOffset`` above its target
    /// position, then springs to full scale at the target position.
    ///
    /// - Parameters:
    ///   - entity: The entity to animate.
    ///   - targetY: The final Y position (surface offset).
    public static func playEntrance(
      on entity: Entity,
      targetY: Float = ARNewsConfiguration.surfacePlacementOffset
    ) async {
      let cfg = ARNewsConfiguration.self

      // Capture the final transform.
      let finalPosition = SIMD3<Float>(
        entity.position.x,
        targetY,
        entity.position.z
      )
      let finalScale = entity.scale

      // Set initial state: small and elevated.
      entity.scale = SIMD3<Float>(repeating: cfg.entranceStartScale)
      entity.position.y = targetY + cfg.entranceDropOffset

      // Animate to final state with spring timing.
      var finalTransform = entity.transform
      finalTransform.scale = finalScale
      finalTransform.translation = finalPosition

      entity.move(
        to: finalTransform,
        relativeTo: entity.parent,
        duration: TimeInterval(cfg.entranceAnimationDuration),
        timingFunction: .easeInOut
      )

      // Wait for animation completion.
      try? await Task.sleep(
        for: .seconds(cfg.entranceAnimationDuration)
      )
    }

    // MARK: - Exit Animation

    /// Plays a shrink-and-fade exit animation.
    ///
    /// The entity scales down to near-zero and rises slightly,
    /// giving the visual impression of being "picked up" before removal.
    ///
    /// - Parameters:
    ///   - entity: The entity to animate.
    ///   - onComplete: Called after the animation completes.
    public static func playExit(
      on entity: Entity,
      onComplete: (() -> Void)? = nil
    ) async {
      let cfg = ARNewsConfiguration.self

      var exitTransform = entity.transform
      exitTransform.scale = SIMD3<Float>(repeating: cfg.entranceStartScale)
      exitTransform.translation.y += cfg.entranceDropOffset * 0.5

      entity.move(
        to: exitTransform,
        relativeTo: entity.parent,
        duration: TimeInterval(cfg.exitAnimationDuration),
        timingFunction: .easeIn
      )

      try? await Task.sleep(
        for: .seconds(cfg.exitAnimationDuration)
      )

      onComplete?()
    }

    // MARK: - Pulse Feedback

    /// Plays a brief scale pulse to acknowledge a user interaction.
    ///
    /// Useful as visual feedback when the user taps an entity
    /// or when a gesture sequence completes.
    ///
    /// - Parameters:
    ///   - entity: The entity to pulse.
    ///   - intensity: Scale multiplier for the pulse (default: 1.05).
    public static func playPulse(
      on entity: Entity,
      intensity: Float = 1.05
    ) async {
      let originalScale = entity.scale
      let pulseDuration: TimeInterval = 0.15

      // Scale up.
      var pulseTransform = entity.transform
      pulseTransform.scale = originalScale * intensity

      entity.move(
        to: pulseTransform,
        relativeTo: entity.parent,
        duration: pulseDuration,
        timingFunction: .easeOut
      )

      try? await Task.sleep(for: .seconds(pulseDuration))

      // Scale back.
      var restoreTransform = entity.transform
      restoreTransform.scale = originalScale

      entity.move(
        to: restoreTransform,
        relativeTo: entity.parent,
        duration: pulseDuration,
        timingFunction: .easeIn
      )

      try? await Task.sleep(for: .seconds(pulseDuration))
    }

    // MARK: - Hover Bob

    /// Applies a subtle continuous hover animation to an entity.
    ///
    /// The entity bobs up and down by a small offset, creating
    /// a "floating" effect that indicates interactivity.
    ///
    /// - Parameters:
    ///   - entity: The entity to animate.
    ///   - amplitude: The bob height in meters (default: 0.005).
    ///   - duration: Full cycle duration in seconds (default: 2.0).
    public static func startHoverBob(
      on entity: Entity,
      amplitude: Float = 0.005,
      duration: TimeInterval = 2.0
    ) {
      let baseY = entity.position.y

      // Create an up position.
      var upTransform = entity.transform
      upTransform.translation.y = baseY + amplitude

      entity.move(
        to: upTransform,
        relativeTo: entity.parent,
        duration: duration / 2,
        timingFunction: .easeInOut
      )

      // Note: For continuous bobbing, the caller should set up
      // a repeating timer or use RealityKit's animation system.
      // This provides the initial "lift" for the first cycle.
    }
  }

#endif
