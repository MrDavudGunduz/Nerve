//
//  CameraRig.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(SceneKit)
  import SceneKit

  // MARK: - CameraRig

  /// Creates and configures the viewer camera.
  ///
  /// Separated from the factory so that camera presets (e.g., close-up,
  /// wide-angle, top-down) can be added as static methods without
  /// touching the main pipeline.
  enum CameraRig {

    /// Creates a camera node with the default viewer configuration.
    ///
    /// - Returns: A `SCNNode` with a configured `SCNCamera` at the
    ///   position defined by ``SceneViewerConfiguration/cameraPosition``.
    static func createCameraNode() -> SCNNode {
      let node = SCNNode()
      let camera = SCNCamera()

      camera.automaticallyAdjustsZRange = true
      camera.fieldOfView = SceneViewerConfiguration.cameraFieldOfView

      node.camera = camera
      node.position = SceneViewerConfiguration.cameraPosition
      node.name = "ViewerCamera"

      return node
    }
  }

#endif
