//
//  SceneLoader.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(SceneKit)
  import SceneKit

  // MARK: - Cross-Platform Color Alias

  #if os(macOS)
    typealias PlatformColor = NSColor
  #else
    typealias PlatformColor = UIColor
  #endif

  // MARK: - SceneLoader

  /// Loads a `SCNScene` from a USDZ file URL or creates a placeholder.
  ///
  /// Encapsulates all file-system and error-handling logic so that
  /// the rest of the pipeline only works with a valid `SCNScene`.
  enum SceneLoader {

    /// Loads a scene from the given URL, or returns a placeholder scene.
    ///
    /// - Parameter url: The local file URL of the USDZ model. Pass `nil`
    ///   to receive a placeholder scene with a translucent cube.
    /// - Returns: A configured `SCNScene` ready for camera and lighting.
    static func loadScene(from url: URL?) -> SCNScene {
      guard let url else {
        return makePlaceholderScene()
      }

      do {
        return try SCNScene(url: url, options: [
          .checkConsistency: true,
        ])
      } catch {
        ModelViewerLog.logger.error(
          "Failed to load SceneKit scene from '\(url.lastPathComponent)': \(error.localizedDescription)"
        )
        return makePlaceholderScene()
      }
    }

    /// Creates a placeholder scene with a chamfered cube.
    ///
    /// Used when no USDZ model URL is available, or when loading fails.
    /// The cube uses a semi-transparent blue material with subtle metalness.
    private static func makePlaceholderScene() -> SCNScene {
      let cfg = SceneViewerConfiguration.self
      let scene = SCNScene()

      let geometry = SCNBox(
        width: cfg.placeholderEdge,
        height: cfg.placeholderEdge,
        length: cfg.placeholderEdge,
        chamferRadius: cfg.placeholderChamfer
      )

      let material = SCNMaterial()
      material.diffuse.contents = PlatformColor.systemBlue
        .withAlphaComponent(cfg.placeholderOpacity)
      material.metalness.contents = cfg.placeholderMetalness
      material.roughness.contents = cfg.placeholderRoughness
      geometry.materials = [material]

      let node = SCNNode(geometry: geometry)
      node.name = "PlaceholderCube"
      scene.rootNode.addChildNode(node)

      return scene
    }
  }

#endif
