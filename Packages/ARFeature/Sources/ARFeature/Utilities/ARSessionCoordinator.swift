//
//  ARSessionCoordinator.swift
//  ARFeature
//
//  Created by Davud Gunduz on 17.05.2026.
//

#if canImport(ARKit) && os(iOS)

  import ARKit
  import Core
  import Foundation
  import OSLog

  // MARK: - ARSessionCoordinator

  /// Bridges ARKit session delegate callbacks to the ``ARNewsViewModel``.
  ///
  /// `ARSessionCoordinator` observes `ARSession` delegate methods and
  /// translates raw ARKit tracking state changes into the domain-specific
  /// ``ARTrackingQuality`` values that ``ARNewsViewModel`` consumes.
  ///
  /// ## Thread Safety
  ///
  /// ARKit delivers delegate callbacks on the main thread when configured
  /// through SwiftUI's `RealityView`. All ViewModel mutations are
  /// `@MainActor`-isolated, ensuring thread-safe state updates.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let coordinator = ARSessionCoordinator(viewModel: viewModel)
  /// arSession.delegate = coordinator
  /// ```
  @MainActor
  public final class ARSessionCoordinator: NSObject, @preconcurrency ARSessionDelegate {

    // MARK: - Properties

    private weak var viewModel: ARNewsViewModel?

    private static let logger = Logger(
      subsystem: LogSubsystem.arFeature,
      category: "ARSessionCoordinator"
    )

    // MARK: - Init

    /// Creates a session coordinator bound to the given view model.
    ///
    /// - Parameter viewModel: The view model to receive tracking updates.
    public init(viewModel: ARNewsViewModel) {
      self.viewModel = viewModel
      super.init()
    }

    // MARK: - ARSessionDelegate

    public nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      let quality = Self.mapTrackingState(camera.trackingState)

      Task { @MainActor [weak self] in
        self?.viewModel?.updateTrackingQuality(quality)
      }
    }

    public nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
      let hasPlaneAnchor = anchors.contains { $0 is ARPlaneAnchor }

      if hasPlaneAnchor {
        Task { @MainActor [weak self] in
          self?.viewModel?.onSurfaceDetected()
        }
      }
    }

    public nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
      Task { @MainActor in
        Self.logger.error(
          "AR session failed: \(error.localizedDescription)"
        )
      }
    }

    public nonisolated func sessionWasInterrupted(_ session: ARSession) {
      Task { @MainActor [weak self] in
        self?.viewModel?.updateTrackingQuality(.unavailable)
        Self.logger.warning("AR session interrupted.")
      }
    }

    public nonisolated func sessionInterruptionEnded(_ session: ARSession) {
      Task { @MainActor [weak self] in
        self?.viewModel?.updateTrackingQuality(.initializing)
        Self.logger.info("AR session interruption ended. Resuming tracking.")
      }
    }

    // MARK: - Mapping

    /// Maps ARKit's tracking state to the domain ``ARTrackingQuality``.
    private nonisolated static func mapTrackingState(
      _ state: ARCamera.TrackingState
    ) -> ARTrackingQuality {
      switch state {
      case .normal:
        return .good
      case .limited(let reason):
        switch reason {
        case .initializing:
          return .initializing
        case .excessiveMotion, .insufficientFeatures, .relocalizing:
          return .limited
        @unknown default:
          return .limited
        }
      case .notAvailable:
        return .unavailable
      }
    }
  }

#endif
