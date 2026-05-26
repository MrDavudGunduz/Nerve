//
//  SpatialAudioEngine.swift
//  ARFeature
//
//  Created by Davud Gunduz on 18.05.2026.
//

#if os(visionOS)

  import AVFoundation
  import Core
  import OSLog
  import RealityKit

  // MARK: - SpatialAudioEngine

  /// Centralized spatial audio feedback engine for visionOS experiences.
  ///
  /// Provides semantically named audio cues for annotation selection,
  /// model interaction events, and scene transitions in volumetric
  /// and immersive space contexts.
  ///
  /// ## Design
  ///
  /// Uses `AVAudioEngine` with `AVAudioEnvironmentNode` for true 3D
  /// spatialized audio on visionOS. System sounds serve as fallback
  /// when custom audio assets are unavailable.
  ///
  /// The engine is designed as a value-type namespace with static methods
  /// — no instance state is required.
  ///
  /// ## Thread Safety
  ///
  /// All methods are `@MainActor`-isolated to match RealityKit's
  /// entity manipulation requirements.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// SpatialAudioEngine.playAnnotationSelect()
  /// SpatialAudioEngine.playModelAttach()
  /// SpatialAudioEngine.playTransition()
  /// ```
  @MainActor
  public enum SpatialAudioEngine {

    // MARK: - Logging

    private static let logger = Logger(
      subsystem: LogSubsystem.arFeature,
      category: "SpatialAudioEngine"
    )

    // MARK: - State

    /// Shared audio engine for spatial audio playback.
    private static var audioEngine: AVAudioEngine?

    /// Environment node for 3D audio spatialization.
    private static var environmentNode: AVAudioEnvironmentNode?

    /// Indicates whether the engine has been successfully initialized.
    private static var isInitialized = false

    // MARK: - Initialization

    /// Initializes the spatial audio engine.
    ///
    /// Call once during app startup or when the first spatial scene loads.
    /// Subsequent calls are no-ops.
    public static func initialize() {
      guard !isInitialized else { return }

      let engine = AVAudioEngine()
      let envNode = AVAudioEnvironmentNode()

      engine.attach(envNode)
      engine.connect(
        envNode,
        to: engine.mainMixerNode,
        format: nil
      )

      // Configure 3D audio rendering.
      envNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
      envNode.renderingAlgorithm = .HRTFHQ

      do {
        try engine.start()
        audioEngine = engine
        environmentNode = envNode
        isInitialized = true
        logger.info("Spatial audio engine initialized successfully.")
      } catch {
        logger.error(
          "Failed to start spatial audio engine: \(error.localizedDescription)"
        )
      }
    }

    /// Shuts down the spatial audio engine and releases resources.
    public static func shutdown() {
      audioEngine?.stop()
      audioEngine = nil
      environmentNode = nil
      isInitialized = false
      logger.info("Spatial audio engine shut down.")
    }

    // MARK: - Audio Cue API

    /// Plays a spatial audio cue when a news annotation is selected.
    ///
    /// A crisp, short selection sound positioned at the annotation's
    /// location in 3D space.
    ///
    /// - Parameter position: Optional 3D position for spatialized playback.
    public static func playAnnotationSelect(
      at position: SIMD3<Float>? = nil
    ) {
      playSpatialCue(
        .annotationSelect,
        at: position,
        volume: SpatialAudioConfiguration.annotationSelectVolume
      )
    }

    /// Plays a spatial audio cue when a 3D model attaches to the scene.
    ///
    /// A satisfying "attach" sound that confirms model placement.
    ///
    /// - Parameter position: Optional 3D position for spatialized playback.
    public static func playModelAttach(
      at position: SIMD3<Float>? = nil
    ) {
      playSpatialCue(
        .modelAttach,
        at: position,
        volume: SpatialAudioConfiguration.modelAttachVolume
      )
    }

    /// Plays a spatial audio cue when a model is detached from the scene.
    ///
    /// - Parameter position: Optional 3D position for spatialized playback.
    public static func playModelDetach(
      at position: SIMD3<Float>? = nil
    ) {
      playSpatialCue(
        .modelDetach,
        at: position,
        volume: SpatialAudioConfiguration.modelDetachVolume
      )
    }

    /// Plays an ambient transition sound for scene mode changes.
    ///
    /// Used when transitioning between 2D → Volumetric → Immersive Space.
    public static func playTransition() {
      playSpatialCue(
        .transition,
        at: nil,
        volume: SpatialAudioConfiguration.transitionVolume
      )
    }

    /// Plays a subtle hover feedback sound.
    ///
    /// Triggered when the user's gaze rests on an interactive element.
    ///
    /// - Parameter position: The 3D position of the hovered element.
    public static func playHoverFeedback(
      at position: SIMD3<Float>? = nil
    ) {
      playSpatialCue(
        .hoverFeedback,
        at: position,
        volume: SpatialAudioConfiguration.hoverFeedbackVolume
      )
    }

    /// Plays a confirmation sound when an immersive space opens.
    public static func playImmersiveOpen() {
      playSpatialCue(
        .immersiveOpen,
        at: nil,
        volume: SpatialAudioConfiguration.immersiveOpenVolume
      )
    }

    /// Plays a closing sound when returning from an immersive space.
    public static func playImmersiveClose() {
      playSpatialCue(
        .immersiveClose,
        at: nil,
        volume: SpatialAudioConfiguration.immersiveCloseVolume
      )
    }

    // MARK: - Private Implementation

    /// The supported spatial audio cue types.
    private enum AudioCue: String {
      case annotationSelect = "annotation_select"
      case modelAttach = "model_attach"
      case modelDetach = "model_detach"
      case transition = "transition"
      case hoverFeedback = "hover_feedback"
      case immersiveOpen = "immersive_open"
      case immersiveClose = "immersive_close"

      /// The system sound ID to use when custom audio is unavailable.
      ///
      /// Maps each cue to an appropriate system sound as fallback.
      var systemSoundFallbackID: UInt32 {
        switch self {
        case .annotationSelect: return 1104  // Tink
        case .modelAttach: return 1057  // Soft thud
        case .modelDetach: return 1105  // Pop
        case .transition: return 1110  // Swoosh
        case .hoverFeedback: return 1103  // Light tick
        case .immersiveOpen: return 1113  // Ascending chime
        case .immersiveClose: return 1114  // Descending chime
        }
      }
    }

    /// Plays a spatial audio cue with optional 3D positioning.
    ///
    /// Attempts to load a custom audio file from the bundle first.
    /// Falls back to system sounds if the custom file is unavailable.
    ///
    /// - Parameters:
    ///   - cue: The audio cue type to play.
    ///   - position: Optional 3D position for spatialization.
    ///   - volume: The playback volume (0.0 – 1.0).
    private static func playSpatialCue(
      _ cue: AudioCue,
      at position: SIMD3<Float>?,
      volume: Float
    ) {
      // Attempt custom audio from bundle.
      if let customURL = Bundle.module.url(
        forResource: cue.rawValue,
        withExtension: "wav"
      ) {
        playCustomAudio(url: customURL, at: position, volume: volume)
        return
      }

      // Attempt .caf format.
      if let customURL = Bundle.module.url(
        forResource: cue.rawValue,
        withExtension: "caf"
      ) {
        playCustomAudio(url: customURL, at: position, volume: volume)
        return
      }

      // Fallback to system sound.
      playSystemSoundFallback(cue.systemSoundFallbackID)
    }

    /// Plays a custom audio file with optional 3D spatialization.
    ///
    /// ## Concurrency Note
    ///
    /// `AVAudioPlayerNode.scheduleFile` accepts a `@Sendable` completion
    /// handler, but both `AVAudioEngine` and `AVAudioPlayerNode` are
    /// non-Sendable. Capturing either in the handler violates Swift 6
    /// strict concurrency. Instead, we schedule cleanup via a timed
    /// `Task.sleep` on MainActor — the delay matches the audio file
    /// duration plus a small buffer, ensuring playback is complete
    /// before detaching.
    private static func playCustomAudio(
      url: URL,
      at position: SIMD3<Float>?,
      volume: Float
    ) {
      guard let engine = audioEngine, let envNode = environmentNode else {
        // Engine not initialized; use system sound.
        logger.warning("Audio engine not initialized, skipping custom audio.")
        return
      }

      do {
        let audioFile = try AVAudioFile(forReading: url)
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        if let position {
          // Connect through environment node for 3D spatialization.
          engine.connect(playerNode, to: envNode, format: audioFile.processingFormat)
          playerNode.position = AVAudio3DPoint(
            x: position.x,
            y: position.y,
            z: position.z
          )
        } else {
          // Non-spatialized: connect directly to mixer.
          engine.connect(
            playerNode,
            to: engine.mainMixerNode,
            format: audioFile.processingFormat
          )
        }

        playerNode.volume = volume
        playerNode.scheduleFile(audioFile, at: nil)
        playerNode.play()

        // Schedule cleanup after the audio finishes.
        // Duration is derived from the file's frame count and sample rate.
        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let cleanupDelay = max(durationSeconds + 0.2, 0.5)  // +200ms buffer, min 500ms.

        Task { @MainActor in
          try? await Task.sleep(for: .seconds(cleanupDelay))
          Self.audioEngine?.detach(playerNode)
        }
      } catch {
        logger.warning(
          "Failed to play custom audio '\(url.lastPathComponent)': \(error.localizedDescription)"
        )
      }
    }

    /// Plays a system sound as fallback.
    private static func playSystemSoundFallback(_ soundID: UInt32) {
      AudioServicesPlaySystemSound(SystemSoundID(soundID))
      logger.debug("Played system sound fallback: \(soundID)")
    }
  }

  // MARK: - SpatialAudioConfiguration

  /// Configuration constants for spatial audio cues.
  ///
  /// Centralizes volume levels and timing parameters so they can
  /// be tuned without modifying the audio engine logic.
  public struct SpatialAudioConfiguration: Sendable {

    // MARK: - Volume Levels

    /// Volume for annotation selection cue (0.0 – 1.0).
    public static let annotationSelectVolume: Float = 0.6

    /// Volume for model attachment cue (0.0 – 1.0).
    public static let modelAttachVolume: Float = 0.7

    /// Volume for model detachment cue (0.0 – 1.0).
    public static let modelDetachVolume: Float = 0.5

    /// Volume for scene transition cue (0.0 – 1.0).
    public static let transitionVolume: Float = 0.4

    /// Volume for hover feedback cue (0.0 – 1.0).
    public static let hoverFeedbackVolume: Float = 0.3

    /// Volume for immersive space opening cue (0.0 – 1.0).
    public static let immersiveOpenVolume: Float = 0.5

    /// Volume for immersive space closing cue (0.0 – 1.0).
    public static let immersiveCloseVolume: Float = 0.5

    // MARK: - Throttling

    /// Minimum interval (seconds) between consecutive hover feedback sounds.
    ///
    /// Prevents audio spam when the user rapidly gazes across multiple elements.
    public static let hoverFeedbackThrottleInterval: TimeInterval = 0.3

    /// Minimum interval (seconds) between consecutive selection sounds.
    public static let selectionThrottleInterval: TimeInterval = 0.15
  }

#endif
