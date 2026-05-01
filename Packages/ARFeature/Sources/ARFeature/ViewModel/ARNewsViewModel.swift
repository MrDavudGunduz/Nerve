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

  // MARK: - Dependencies

  private let assetManager: ARAssetManager
  private let capabilityChecker: ARCapabilityChecker

  // MARK: - Internal

  private var loadTask: Task<Void, Never>?

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
          return
        }

        // Attempt remote download.
        try await assetManager.downloadAndCache(asset)

        if let localURL = await assetManager.localURL(for: asset) {
          self.modelURL = localURL
          self.modelState = .loaded
          Self.logger.info("Model '\(modelName)' downloaded and cached.")
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
  }

  // MARK: - Gesture State

  /// Clamps the scale to configured bounds.
  ///
  /// - Parameter proposedScale: The raw scale from the gesture recognizer.
  /// - Returns: The clamped scale value.
  public func clampedScale(_ proposedScale: Float) -> Float {
    min(
      max(proposedScale, ARNewsConfiguration.minScale),
      ARNewsConfiguration.maxScale
    )
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
}
