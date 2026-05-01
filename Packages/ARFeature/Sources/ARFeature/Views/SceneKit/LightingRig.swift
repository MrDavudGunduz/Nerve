//
//  LightingRig.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(SceneKit)
  import SceneKit

  // MARK: - LightingRig

  /// Applies a cinematic three-point lighting setup to a scene.
  ///
  /// The rig consists of:
  /// - **Key light** — primary illumination with shadow casting.
  /// - **Fill light** — softens shadows on the opposite side.
  /// - **Ambient light** — base illumination to prevent pure-black areas.
  ///
  /// All intensity and angle values are sourced from ``SceneViewerConfiguration``.
  enum LightingRig {

    /// Adds key, fill, and ambient lights to the scene's root node.
    ///
    /// - Parameter scene: The scene to illuminate.
    static func applyStudioLighting(to scene: SCNScene) {
      let root = scene.rootNode
      root.addChildNode(makeKeyLight())
      root.addChildNode(makeFillLight())
      root.addChildNode(makeAmbientLight())
    }

    // MARK: - Light Constructors

    /// Primary directional light with shadow casting.
    private static func makeKeyLight() -> SCNNode {
      let cfg = SceneViewerConfiguration.self
      let node = SCNNode()
      let light = SCNLight()

      light.type = .directional
      light.intensity = cfg.keyLightIntensity
      light.color = PlatformColor.white
      light.castsShadow = true
      light.shadowMode = .deferred

      node.light = light
      node.eulerAngles = cfg.keyLightAngles
      node.name = "KeyLight"

      return node
    }

    /// Secondary fill light — softens shadows.
    private static func makeFillLight() -> SCNNode {
      let cfg = SceneViewerConfiguration.self
      let node = SCNNode()
      let light = SCNLight()

      light.type = .directional
      light.intensity = cfg.fillLightIntensity
      light.color = PlatformColor(white: cfg.fillLightWhiteness, alpha: 1)

      node.light = light
      node.eulerAngles = cfg.fillLightAngles
      node.name = "FillLight"

      return node
    }

    /// Ambient fill — prevents pure-black regions.
    private static func makeAmbientLight() -> SCNNode {
      let cfg = SceneViewerConfiguration.self
      let node = SCNNode()
      let light = SCNLight()

      light.type = .ambient
      light.intensity = cfg.ambientLightIntensity
      light.color = PlatformColor(white: cfg.ambientLightWhiteness, alpha: 1)

      node.light = light
      node.name = "AmbientLight"

      return node
    }
  }

#endif
