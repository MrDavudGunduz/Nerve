//
//  SceneViewFactory.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(SceneKit)
  import SceneKit

  // MARK: - SceneViewFactory

  /// Configures and returns a fully-assembled `SCNView`.
  ///
  /// This factory composes the three single-responsibility builders
  /// (``SceneLoader``, ``LightingRig``, ``SceneAnimator``) and
  /// attaches a ``CameraRig`` — each of which can be tested and
  /// modified independently.
  ///
  /// ## Pipeline
  ///
  /// ```
  /// SceneLoader  →  model scene or placeholder
  ///       ↓
  /// CameraRig    →  camera node attached
  ///       ↓
  /// LightingRig  →  three-point lights added
  ///       ↓
  /// SceneAnimator→  auto-rotation applied
  ///       ↓
  /// SCNView      →  configured and returned
  /// ```
  @MainActor
  enum SceneViewFactory {

    @MainActor
    static func makeView(modelURL: URL?) -> SCNView {
      let sceneView = SCNView()
      sceneView.antialiasingMode = .multisampling4X
      sceneView.autoenablesDefaultLighting = false
      sceneView.allowsCameraControl = true
      sceneView.backgroundColor = .clear

      // 1. Load or create the scene.
      let scene = SceneLoader.loadScene(from: modelURL)

      // 2. Attach camera.
      let cameraNode = CameraRig.createCameraNode()
      scene.rootNode.addChildNode(cameraNode)

      // 3. Apply three-point studio lighting.
      LightingRig.applyStudioLighting(to: scene)

      // 4. Add auto-rotation on model content.
      SceneAnimator.addAutoRotation(to: scene)

      sceneView.scene = scene
      sceneView.pointOfView = cameraNode

      return sceneView
    }
  }

#endif
