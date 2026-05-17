//
//  ARNewsViewModel.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import Foundation
import OSLog
import SwiftUI

// MARK: - ARModelState

/// Represents the lifecycle state of a 3D model in the AR viewer.
///
/// Drives the UI: the view observes this state to switch between
/// loading indicators, the rendered model, and error messages.
public enum ARModelState: Sendable, Equatable {
  /// No model has been requested yet.
  case idle
  /// The model is being loaded from bundle, cache, or network.
  case loading
  /// The model is loaded and ready for display.
  case loaded
  /// The model failed to load.
  case failed(String)
}

// MARK: - ARNewsViewModel

/// Drives the AR news viewer experience.
///
/// Determines the appropriate viewer mode (AR / spatial / model viewer)
/// based on device capabilities, manages model loading state, and provides
/// the ``NewsItem`` data for the overlay card.
///
/// ## Architecture
///
/// `ARNewsViewModel` is an `@Observable` class that bridges:
/// - **Input:** ``NewsItem`` + ``ARCapabilityChecker`` + ``ARAssetManager``
/// - **Output:** ``ARModelState`` + ``ARViewerMode`` consumed by SwiftUI views
///
/// The ViewModel does **not** import RealityKit or ARKit — it only manages
/// state. Platform-specific rendering logic lives in the views.
///
/// ## State Machine
///
/// ```
/// idle → loading → loaded → (interactive)
///                ↘ failed → (retry) → loading
///
/// Placement:
/// coaching → surfaceDetected → animatingEntrance → placed
///          ↘ (skip/timeout) → placed (floating fallback)
/// ```
///
/// ## Concurrency
///
/// Model loading is dispatched via structured concurrency (`Task`).
/// The `@MainActor` annotation ensures all published state mutations
/// happen on the main thread for safe UI binding.
@MainActor
@Observable
public final class ARNewsViewModel {

  // MARK: - Published State

  /// The current state of the 3D model.
  public private(set) var modelState: ARModelState = .idle

  /// The recommended viewer mode for the current device.
  public let viewerMode: ARViewerMode

  /// The news item being displayed.
  public let newsItem: NewsItem

  /// The local file URL of the USDZ model, once resolved.
  public private(set) var modelURL: URL?

  /// Current scale applied by the user's pinch gesture.
  public var currentScale: Float = 1.0

  /// Current Y-axis rotation applied by the user's rotation gesture (radians).
  public var currentRotation: Float = 0.0

  /// Whether the informational overlay card is visible.
  public var isOverlayVisible: Bool = true

  // MARK: - AR Session State

  /// The current tracking quality reported by ARKit.
  ///
  /// Updated by the AR content view's session delegate.
  /// Non-AR modes (SceneKit fallback) leave this as `.good`.
  public private(set) var trackingQuality: ARTrackingQuality = .initializing

  /// The current placement state for the entity in the AR session.
  ///
  /// Drives the coaching overlay visibility and entrance animation.
  public private(set) var placementState: ARPlacementState = .coaching

  /// Whether the coaching overlay should be displayed.
  ///
  /// Computed from ``placementState`` and ``ARNewsConfiguration/showCoachingOverlay``.
  public var showCoaching: Bool {
    guard ARNewsConfiguration.showCoachingOverlay else { return false }
    return placementState == .coaching && viewerMode == .augmentedReality
  }

  /// The coaching state for the coaching overlay.
  ///
  /// Derived from ``trackingQuality`` and ``placementState``.
  public var coachingState: CoachingState {
    switch placementState {
    case .coaching:
      switch trackingQuality {
      case .good, .limited:
        return .scanning
      case .initializing:
        return .scanning
      case .unavailable:
        return .timeout
      }
    case .surfaceDetected:
      return .detected
    default:
      return .scanning
    }
  }

  // MARK: - Dependencies

  private let assetManager: ARAssetManager
  private let capabilityChecker: ARCapabilityChecker

  // MARK: - Internal

  private var loadTask: Task<Void, Never>?
  private var coachingTimeoutTask: Task<Void, Never>?

  /// Tracked handle for the auto-advance delay after surface detection.
  ///
  /// Without tracking, a `reset()` during the 0.8s delay would not cancel
  /// the pending `beginEntityPlacement()` call, causing a state corruption
  /// where placement begins after the ViewModel has been reset.
  private var surfaceAdvanceTask: Task<Void, Never>?

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ARNewsViewModel"
  )

  // MARK: - Init

  /// Creates a new AR news view model.
  ///
  /// - Parameters:
  ///   - newsItem: The news item to display in AR.
  ///   - assetManager: The asset manager for model resolution.
  ///   - capabilityChecker: The capability checker for viewer mode selection.
  public init(
    newsItem: NewsItem,
    assetManager: ARAssetManager = ARAssetManager(),
    capabilityChecker: ARCapabilityChecker = ARCapabilityChecker()
  ) {
    self.newsItem = newsItem
    self.assetManager = assetManager
    self.capabilityChecker = capabilityChecker
    self.viewerMode = capabilityChecker.recommendedViewerMode

    // Non-AR modes skip the coaching flow entirely.
    if viewerMode != .augmentedReality {
      placementState = .placed
      trackingQuality = .good
    }
  }

  // MARK: - Model Loading

  /// Begins loading the 3D model for the current news item.
  ///
  /// This method is idempotent — calling it while already loading
  /// or after a successful load is a no-op.
  public func loadModel() {
    guard modelState == .idle || isRetryableState else { return }

    modelState = .loading

    loadTask = Task { [weak self] in
      guard let self else { return }

      guard let modelName = newsItem.arModelName else {
        self.modelState = .failed("No 3D model available for this story.")
        Self.logger.warning(
          "No AR model name for news item '\(self.newsItem.id)'."
        )
        return
      }

      let asset = ARModelAsset(
        name: modelName,
        displayName: newsItem.headline
      )

      do {
        // Try local resolution first.
        if let localURL = await assetManager.localURL(for: asset) {
          self.modelURL = localURL
          self.modelState = .loaded
          Self.logger.info("Model '\(modelName)' loaded from local storage.")
          startCoachingTimeout()
          return
        }

        // Attempt remote download.
        try await assetManager.downloadAndCache(asset)

        if let localURL = await assetManager.localURL(for: asset) {
          self.modelURL = localURL
          self.modelState = .loaded
          Self.logger.info("Model '\(modelName)' downloaded and cached.")
          startCoachingTimeout()
        } else {
          self.modelState = .failed("Model download succeeded but file not found.")
          Self.logger.error("Model '\(modelName)' cached but localURL returned nil.")
        }
      } catch {
        self.modelState = .failed(error.localizedDescription)
        Self.logger.error(
          "Failed to load model '\(modelName)': \(error.localizedDescription)"
        )
      }
    }
  }

  /// Cancels any in-progress model loading.
  public func cancelLoading() {
    loadTask?.cancel()
    loadTask = nil
    coachingTimeoutTask?.cancel()
    coachingTimeoutTask = nil
    surfaceAdvanceTask?.cancel()
    surfaceAdvanceTask = nil
    if modelState == .loading {
      modelState = .idle
    }
  }

  /// Resets the viewer to its initial state.
  ///
  /// Cancels loading, clears the model URL, and resets gesture state.
  public func reset() {
    cancelLoading()
    modelURL = nil
    modelState = .idle
    currentScale = 1.0
    currentRotation = 0.0
    isOverlayVisible = true

    // Mirror init() logic: non-AR modes skip coaching entirely.
    if viewerMode == .augmentedReality {
      trackingQuality = .initializing
      placementState = .coaching
    } else {
      trackingQuality = .good
      placementState = .placed
    }
  }

  // MARK: - AR Session Updates

  /// Updates the tracking quality from the AR session delegate.
  ///
  /// Called by the AR content view when ARKit reports tracking state changes.
  ///
  /// - Parameter quality: The new tracking quality.
  public func updateTrackingQuality(_ quality: ARTrackingQuality) {
    let previousQuality = trackingQuality
    trackingQuality = quality

    // Log significant transitions.
    if previousQuality != quality {
      Self.logger.info("Tracking quality changed: \(previousQuality.rawValue) → \(quality.rawValue)")
    }
  }

  /// Called when a horizontal surface is detected by ARKit.
  ///
  /// Transitions the placement state from `.coaching` to `.surfaceDetected`
  /// and schedules auto-advancement to placement after a brief pause.
  /// The delay task is tracked via ``surfaceAdvanceTask`` so it can be
  /// cancelled if ``reset()`` or ``cancelLoading()`` is called.
  public func onSurfaceDetected() {
    guard placementState == .coaching else { return }

    placementState = .surfaceDetected
    Self.logger.info("Horizontal surface detected.")

    // Auto-advance to placement after a brief pause.
    // Tracked so reset()/cancelLoading() can cancel it.
    surfaceAdvanceTask?.cancel()
    surfaceAdvanceTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(0.8))
      guard let self, !Task.isCancelled,
        self.placementState == .surfaceDetected
      else { return }
      self.beginEntityPlacement()
    }
  }

  /// Transitions to the entrance animation state.
  ///
  /// Called when the entity is about to be placed on the detected surface.
  public func beginEntityPlacement() {
    placementState = .animatingEntrance
    Self.logger.info("Beginning entity placement with entrance animation.")

    #if os(iOS)
      ARHapticEngine.playPlacement()
    #endif
  }

  /// Marks the entity as fully placed and interactive.
  ///
  /// Called after the entrance animation completes.
  public func completeEntityPlacement() {
    placementState = .placed
    Self.logger.info("Entity placement complete. Model is interactive.")
  }

  /// Skips the coaching overlay and places the model immediately.
  ///
  /// Used when the user taps "Skip" or the coaching timeout fires.
  /// The model is placed at a default distance in front of the camera.
  public func skipCoaching() {
    coachingTimeoutTask?.cancel()
    coachingTimeoutTask = nil

    Self.logger.info("Coaching skipped. Using fallback placement.")
    beginEntityPlacement()
  }

  // MARK: - Gesture State

  /// Clamps the scale to configured bounds.
  ///
  /// - Parameter proposedScale: The raw scale from the gesture recognizer.
  /// - Returns: The clamped scale value.
  public func clampedScale(_ proposedScale: Float) -> Float {
    let clamped = min(
      max(proposedScale, ARNewsConfiguration.minScale),
      ARNewsConfiguration.maxScale
    )

    // Trigger haptic if hitting limits.
    #if os(iOS)
      if clamped != proposedScale {
        ARHapticEngine.playLimitReached()
      }
    #endif

    return clamped
  }

  // MARK: - Convenience

  /// The credibility label for the news item, if analysis is available.
  public var credibilityLabel: CredibilityLabel? {
    newsItem.analysis?.credibilityLabel
  }

  /// The formatted publication date string.
  public var formattedDate: String {
    newsItem.publishedAt.formatted(
      .dateTime.month(.abbreviated).day().year()
    )
  }

  // MARK: - Private

  private var isRetryableState: Bool {
    if case .failed = modelState { return true }
    return false
  }

  /// Starts the coaching timeout timer.
  ///
  /// If no surface is detected within ``ARNewsConfiguration/coachingTimeoutDuration``,
  /// the coaching overlay is automatically dismissed and the model is placed
  /// at a default position.
  private func startCoachingTimeout() {
    guard viewerMode == .augmentedReality,
      placementState == .coaching
    else { return }

    coachingTimeoutTask = Task { [weak self] in
      try? await Task.sleep(
        for: .seconds(ARNewsConfiguration.coachingTimeoutDuration)
      )

      guard let self, self.placementState == .coaching else { return }
      Self.logger.warning("Coaching timed out after \(ARNewsConfiguration.coachingTimeoutDuration)s.")
      self.skipCoaching()
    }
  }
}
