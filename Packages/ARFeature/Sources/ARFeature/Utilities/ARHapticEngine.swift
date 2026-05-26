//
//  ARHapticEngine.swift
//  ARFeature
//
//  Created by Davud Gunduz on 16.05.2026.
//

#if os(iOS)
  import Core
  import CoreHaptics
  import OSLog
  import UIKit

  // MARK: - ARHapticEngine

  /// Centralized haptic feedback engine for AR interactions.
  ///
  /// Provides semantically named haptic events (placement, gesture start,
  /// limit reached) that map to Core Haptics patterns. Falls back to
  /// `UIImpactFeedbackGenerator` on devices without Core Haptics support.
  ///
  /// ## Thread Safety
  ///
  /// All methods are `@MainActor`-isolated because haptic APIs must be
  /// called from the main thread. The engine is designed as a value-type
  /// namespace with static methods — no instance state to manage.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// ARHapticEngine.playPlacement()   // Model placed on surface
  /// ARHapticEngine.playGestureStart() // User begins drag/scale/rotate
  /// ARHapticEngine.playLimitReached() // Scale/rotation at min/max
  /// ```
  @MainActor
  public enum ARHapticEngine {

    // MARK: - Logging

    private static let logger = Logger(
      subsystem: LogSubsystem.arFeature,
      category: "ARHapticEngine"
    )

    // MARK: - Core Haptics Engine

    /// Lazily initialized Core Haptics engine.
    ///
    /// Returns `nil` on devices without haptic hardware (e.g., iPad, Simulator).
    /// All play methods fall back gracefully when this is `nil`.
    private static var coreEngine: CHHapticEngine? = {
      guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
        logger.info("Device does not support Core Haptics. Using UIKit fallback.")
        return nil
      }

      do {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true

        // Auto-restart on interruption (e.g., phone call).
        engine.resetHandler = {
          do {
            try engine.start()
          } catch {
            logger.error(
              "Failed to restart haptic engine: \(error.localizedDescription)"
            )
          }
        }

        try engine.start()
        return engine
      } catch {
        logger.error(
          "Failed to initialize Core Haptics: \(error.localizedDescription)"
        )
        return nil
      }
    }()

    // MARK: - Public API

    /// Plays a satisfying "thud" haptic when a 3D model is placed on a surface.
    ///
    /// Uses a sharp transient followed by a brief continuous rumble
    /// to simulate physical impact.
    public static func playPlacement() {
      guard let engine = coreEngine else {
        // UIKit fallback.
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(
          intensity: CGFloat(ARNewsConfiguration.placementHapticIntensity)
        )
        return
      }

      let intensity = CHHapticEventParameter(
        parameterID: .hapticIntensity,
        value: ARNewsConfiguration.placementHapticIntensity
      )
      let sharpness = CHHapticEventParameter(
        parameterID: .hapticSharpness,
        value: 0.8
      )

      let events: [CHHapticEvent] = [
        // Initial impact.
        CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [intensity, sharpness],
          relativeTime: 0
        ),
        // Settling rumble.
        CHHapticEvent(
          eventType: .hapticContinuous,
          parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
          ],
          relativeTime: 0.05,
          duration: 0.15
        ),
      ]

      playPattern(events, on: engine)
    }

    /// Plays a light tap when the user begins a gesture interaction.
    public static func playGestureStart() {
      guard let engine = coreEngine else {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(
          intensity: CGFloat(ARNewsConfiguration.gestureStartHapticIntensity)
        )
        return
      }

      let events: [CHHapticEvent] = [
        CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [
            CHHapticEventParameter(
              parameterID: .hapticIntensity,
              value: ARNewsConfiguration.gestureStartHapticIntensity
            ),
            CHHapticEventParameter(
              parameterID: .hapticSharpness,
              value: 0.5
            ),
          ],
          relativeTime: 0
        ),
      ]

      playPattern(events, on: engine)
    }

    /// Plays a double-tap when a gesture value reaches its configured limit.
    ///
    /// Signals to the user that scale or rotation cannot go further.
    public static func playLimitReached() {
      guard let engine = coreEngine else {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        return
      }

      let intensity = CHHapticEventParameter(
        parameterID: .hapticIntensity,
        value: ARNewsConfiguration.limitReachedHapticIntensity
      )
      let sharpness = CHHapticEventParameter(
        parameterID: .hapticSharpness,
        value: 0.9
      )

      let events: [CHHapticEvent] = [
        CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [intensity, sharpness],
          relativeTime: 0
        ),
        CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [intensity, sharpness],
          relativeTime: 0.1
        ),
      ]

      playPattern(events, on: engine)
    }

    /// Plays a subtle selection haptic for UI interactions (e.g., overlay toggle).
    public static func playSelection() {
      UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Private

    private static func playPattern(
      _ events: [CHHapticEvent],
      on engine: CHHapticEngine
    ) {
      do {
        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: CHHapticTimeImmediate)
      } catch {
        logger.warning(
          "Haptic playback failed: \(error.localizedDescription)"
        )
      }
    }
  }

#endif
