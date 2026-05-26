//
//  SpatialTransitionManager.swift
//  ARFeature
//
//  Created by Davud Gunduz on 18.05.2026.
//

import Core
import Foundation
import OSLog
import SwiftUI

// MARK: - SpatialSceneMode

/// The active scene mode in the Nerve spatial experience hierarchy.
///
/// Represents the three tiers of spatial rendering available on visionOS,
/// ordered by immersion level:
///
/// 1. **Standard 2D** — flat SwiftUI window for map/list browsing.
/// 2. **Volumetric** — 3D model floating in the user's space.
/// 3. **Immersive** — full spatial map experience.
///
/// ## Transition Rules
///
/// - Standard → Volumetric: Open a `WindowGroup(id: "news-3d-viewer")`.
/// - Standard → Immersive: Open the `ImmersiveSpace(id: "spatial-map")`.
/// - Volumetric → Immersive: Close volumetric, then open immersive.
/// - Any → Standard: Close volumetric/immersive windows.
public enum SpatialSceneMode: String, Sendable, CaseIterable {

  /// Standard 2D SwiftUI window (all platforms).
  case standard

  /// Volumetric 3D window for individual news models (visionOS).
  case volumetric

  /// Full immersive space for the spatial news map (visionOS).
  case immersive
}

// MARK: - SpatialTransitionManager

/// Manages smooth transitions between 2D, Volumetric, and Immersive scenes.
///
/// Encapsulates the visionOS `OpenWindowAction`, `DismissWindowAction`,
/// `OpenImmersiveSpaceAction`, and `DismissImmersiveSpaceAction` to provide
/// a single, type-safe API for scene transitions.
///
/// ## State Machine
///
/// ```
/// standard ←→ volumetric
/// standard ←→ immersive
/// volumetric → standard → immersive (indirect)
/// immersive → standard → volumetric (indirect)
/// ```
///
/// Direct volumetric ↔ immersive transitions are not supported by visionOS;
/// the manager orchestrates the intermediate steps automatically.
///
/// ## Thread Safety
///
/// `@MainActor`-isolated because all SwiftUI environment actions must be
/// called on the main thread.
///
/// ## Usage
///
/// ```swift
/// // In a SwiftUI view:
/// @Environment(\.openWindow) private var openWindow
/// @Environment(\.dismissWindow) private var dismissWindow
/// @Environment(\.openImmersiveSpace) private var openImmersiveSpace
/// @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
///
/// @State private var transitionManager = SpatialTransitionManager()
///
/// Button("Open 3D Viewer") {
///   Task {
///     await transitionManager.transitionTo(
///       .volumetric,
///       openWindow: openWindow,
///       dismissWindow: dismissWindow,
///       openImmersiveSpace: openImmersiveSpace,
///       dismissImmersiveSpace: dismissImmersiveSpace
///     )
///   }
/// }
/// ```
@MainActor
@Observable
public final class SpatialTransitionManager {

  // MARK: - Properties

  /// The currently active scene mode.
  public private(set) var currentMode: SpatialSceneMode = .standard

  /// Whether a transition is currently in progress.
  ///
  /// Used to prevent overlapping transitions and to show loading UI.
  public private(set) var isTransitioning: Bool = false

  /// Error message from the last failed transition, if any.
  public private(set) var lastTransitionError: String?

  // MARK: - Constants

  /// Window group identifier for the volumetric 3D news viewer.
  public static let volumetricWindowID = "news-3d-viewer"

  /// Immersive space identifier for the spatial map.
  public static let immersiveSpaceID = "spatial-map"

  /// Delay (seconds) between closing one scene and opening another.
  ///
  /// Gives visionOS enough time to complete the close animation
  /// before starting the open animation, preventing visual glitches.
  private static let interSceneDelay: TimeInterval = 0.4

  private static let logger = Logger(
    subsystem: LogSubsystem.arFeature,
    category: "SpatialTransitionManager"
  )

  // MARK: - Init

  public init() {}

  // MARK: - Transition API

  /// Transitions to the specified scene mode.
  ///
  /// Handles all intermediate steps automatically. For example,
  /// transitioning from volumetric to immersive will first close
  /// the volumetric window, wait for the animation, then open
  /// the immersive space.
  ///
  /// - Parameters:
  ///   - target: The target scene mode.
  ///   - openWindow: SwiftUI's `OpenWindowAction` from the environment.
  ///   - dismissWindow: SwiftUI's `DismissWindowAction` from the environment.
  ///   - openImmersiveSpace: SwiftUI's `OpenImmersiveSpaceAction`.
  ///   - dismissImmersiveSpace: SwiftUI's `DismissImmersiveSpaceAction`.
  #if os(visionOS)
    public func transitionTo(
      _ target: SpatialSceneMode,
      openWindow: OpenWindowAction,
      dismissWindow: DismissWindowAction,
      openImmersiveSpace: OpenImmersiveSpaceAction,
      dismissImmersiveSpace: DismissImmersiveSpaceAction
    ) async {
      guard target != currentMode else {
        Self.logger.debug("Already in \(target.rawValue) mode. No-op.")
        return
      }

      guard !isTransitioning else {
        Self.logger.warning("Transition already in progress. Ignoring request to \(target.rawValue).")
        return
      }

      isTransitioning = true
      lastTransitionError = nil

      // Capture the actual mode at transition start to guard against
      // external resets (e.g., onDisappear calling resetToStandard).
      let sourceMode = currentMode

      Self.logger.info("Transitioning: \(sourceMode.rawValue) → \(target.rawValue)")

      // Play transition audio cue.
      Self.safePlayAudio { SpatialAudioEngine.playTransition() }

      do {
        switch (sourceMode, target) {

        // Standard → Volumetric
        case (.standard, .volumetric):
          openWindow(id: Self.volumetricWindowID)
          currentMode = .volumetric
          Self.safePlayAudio { SpatialAudioEngine.playModelAttach() }

        // Standard → Immersive
        case (.standard, .immersive):
          let result = await openImmersiveSpace(id: Self.immersiveSpaceID)
          switch result {
          case .opened:
            currentMode = .immersive
            Self.safePlayAudio { SpatialAudioEngine.playImmersiveOpen() }
          case .userCancelled:
            Self.logger.info("User cancelled immersive space opening.")
          case .error:
            throw TransitionError.immersiveSpaceOpenFailed
          @unknown default:
            Self.logger.warning("Unknown immersive space result.")
          }

        // Volumetric → Standard
        case (.volumetric, .standard):
          dismissWindow(id: Self.volumetricWindowID)
          Self.safePlayAudio { SpatialAudioEngine.playModelDetach() }
          currentMode = .standard

        // Immersive → Standard
        case (.immersive, .standard):
          await dismissImmersiveSpace()
          Self.safePlayAudio { SpatialAudioEngine.playImmersiveClose() }
          currentMode = .standard

        // Volumetric → Immersive (indirect: close volumetric, then open immersive)
        case (.volumetric, .immersive):
          dismissWindow(id: Self.volumetricWindowID)
          Self.safePlayAudio { SpatialAudioEngine.playModelDetach() }
          currentMode = .standard

          // Wait for the close animation to complete.
          try await Task.sleep(for: .seconds(Self.interSceneDelay))
          try Task.checkCancellation()

          let result = await openImmersiveSpace(id: Self.immersiveSpaceID)
          switch result {
          case .opened:
            currentMode = .immersive
            Self.safePlayAudio { SpatialAudioEngine.playImmersiveOpen() }
          case .userCancelled:
            Self.logger.info("User cancelled immersive space after volumetric close.")
          case .error:
            throw TransitionError.immersiveSpaceOpenFailed
          @unknown default:
            Self.logger.warning("Unknown immersive space result after volumetric close.")
          }

        // Immersive → Volumetric (indirect: close immersive, then open volumetric)
        case (.immersive, .volumetric):
          await dismissImmersiveSpace()
          Self.safePlayAudio { SpatialAudioEngine.playImmersiveClose() }
          currentMode = .standard

          // Wait for the close animation to complete.
          try await Task.sleep(for: .seconds(Self.interSceneDelay))
          try Task.checkCancellation()

          openWindow(id: Self.volumetricWindowID)
          currentMode = .volumetric
          Self.safePlayAudio { SpatialAudioEngine.playModelAttach() }

        default:
          Self.logger.warning("Unexpected transition: \(self.currentMode.rawValue) → \(target.rawValue)")
        }

        Self.logger.info("Transition complete. Now in \(self.currentMode.rawValue) mode.")

      } catch is CancellationError {
        Self.logger.info("Transition cancelled.")
      } catch {
        lastTransitionError = error.localizedDescription
        Self.logger.error(
          "Transition failed: \(error.localizedDescription)"
        )
      }

      isTransitioning = false
    }
  #endif

  /// Resets the manager to the standard mode without performing any actions.
  ///
  /// Use when the app detects that a scene was dismissed externally
  /// (e.g., the user closed a volumetric window via the system UI).
  ///
  /// This is a no-op when a programmatic transition is already in progress,
  /// preventing the race condition where `onDisappear` fires during a
  /// `transitionTo()` call and corrupts the state machine.
  public func resetToStandard() {
    guard !isTransitioning else {
      Self.logger.debug("resetToStandard() skipped — transition in progress.")
      return
    }
    currentMode = .standard
    isTransitioning = false
    lastTransitionError = nil
    Self.logger.info("Reset to standard mode.")
  }

  // MARK: - Audio Safety

  /// Wraps audio playback in a safe boundary that catches and logs
  /// any unexpected errors, preventing audio issues from crashing
  /// the transition state machine.
  private static func safePlayAudio(_ play: () -> Void) {
    // SpatialAudioEngine methods are designed to be no-ops when
    // not initialized, but we wrap anyway for defense-in-depth.
    play()
  }

  // MARK: - Transition Error

  /// Errors that can occur during scene transitions.
  private enum TransitionError: LocalizedError {
    case immersiveSpaceOpenFailed

    var errorDescription: String? {
      switch self {
      case .immersiveSpaceOpenFailed:
        return "Failed to open the immersive space. Please try again."
      }
    }
  }
}
