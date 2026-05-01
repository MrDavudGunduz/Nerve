//
//  SceneAnimator.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(SceneKit)
  import SceneKit

  // MARK: - SceneAnimator

  /// Manages idle animations applied to the 3D model content.
  ///
  /// Currently provides a single slow Y-axis auto-rotation.
  /// Future enhancements (e.g., bob, pulse, spotlight sweep)
  /// can be added here without touching the view layer.
  enum SceneAnimator {

    /// Wraps model content in a container node and applies a perpetual Y-axis rotation.
    ///
    /// All child nodes of `scene.rootNode` that are **not** cameras or lights
    /// are re-parented into a `ContentContainer` node, which then receives
    /// the rotation action. This prevents the camera and lights from rotating.
    ///
    /// - Parameter scene: The scene whose model content should rotate.
    static func addAutoRotation(to scene: SCNScene) {
      let container = SCNNode()
      container.name = "ContentContainer"

      // Re-parent model geometry, preserving cameras and lights in place.
      let modelChildren = scene.rootNode.childNodes.filter { node in
        node.camera == nil && node.light == nil
      }
      for child in modelChildren {
        child.removeFromParentNode()
        container.addChildNode(child)
      }

      scene.rootNode.addChildNode(container)

      // Perpetual 360° rotation.
      let fullRotation = SCNAction.rotateBy(
        x: 0,
        y: .pi * 2,
        z: 0,
        duration: SceneViewerConfiguration.autoRotationDuration
      )
      container.runAction(.repeatForever(fullRotation))
    }
  }

#endif
