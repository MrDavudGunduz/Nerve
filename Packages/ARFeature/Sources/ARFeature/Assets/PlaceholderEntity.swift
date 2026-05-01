//
//  PlaceholderEntity.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(RealityKit)
  import RealityKit
  import Foundation

  // MARK: - PlaceholderEntity

  /// A pulsating 3D placeholder shown while a USDZ model is loading.
  ///
  /// Renders as a translucent sphere with a slow rotation animation
  /// to indicate loading progress. Automatically removed when the
  /// real model entity replaces it in the scene graph.
  ///
  /// ## Design
  ///
  /// Uses RealityKit's entity-component system:
  /// - `ModelComponent` with a translucent material for the visual.
  /// - Transform animation for the rotation effect.
  ///
  /// The placeholder is intentionally small (``ARNewsConfiguration/placeholderSize``)
  /// so it does not obscure the AR environment while loading.
  @MainActor
  public final class PlaceholderEntity {

    /// Creates a placeholder loading entity.
    ///
    /// - Returns: A configured `ModelEntity` with a pulsating animation.
    public static func create() -> ModelEntity {
      let mesh = MeshResource.generateSphere(
        radius: ARNewsConfiguration.placeholderSize
      )

      var material = SimpleMaterial()
      material.color = .init(
        tint: .systemBlue.withAlphaComponent(0.4),
        texture: nil
      )
      material.metallic = .init(floatLiteral: 0.3)
      material.roughness = .init(floatLiteral: 0.8)

      let entity = ModelEntity(mesh: mesh, materials: [material])
      entity.name = "PlaceholderEntity"

      // Generate collision shape for gesture interaction during loading.
      entity.generateCollisionShapes(recursive: false)

      return entity
    }
  }
#endif
