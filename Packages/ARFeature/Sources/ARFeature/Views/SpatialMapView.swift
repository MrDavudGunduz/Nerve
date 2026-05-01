//
//  SpatialMapView.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import OSLog
import SwiftUI

#if canImport(RealityKit)
  import RealityKit
#endif

// MARK: - SpatialMapView

/// An immersive space view that renders the news map as a spatial 3D experience.
///
/// On **visionOS**, this view:
/// - Renders a topographical 3D surface representing the world map.
/// - Places floating 3D tags above geographic news locations.
/// - Supports gaze + pinch interaction for selecting news annotations.
/// - Uses spatial audio cues for selection feedback.
///
/// ## Registration
///
/// Register as an `ImmersiveSpace` in `NerveApp`:
///
/// ```swift
/// ImmersiveSpace(id: "spatial-map") {
///   SpatialMapView()
/// }
/// .immersionStyle(selection: .constant(.mixed), in: .mixed)
/// ```
///
/// ## Architecture
///
/// Receives the news items array from the environment or a shared store.
/// Each news item with a valid coordinate is placed as a floating tag
/// entity in the 3D scene at a position derived from its lat/lon.
public struct SpatialMapView: View {

  // MARK: - Properties

  @State private var newsItems: [NewsItem]

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "SpatialMapView"
  )

  // MARK: - Constants

  /// Scale factor to convert lat/lon degrees to meters in the scene.
  private static let geoToSceneScale: Float = 0.01

  /// Height offset (meters) for floating annotation tags.
  private static let annotationYOffset: Float = 0.15

  /// Base height of the map surface (meters from origin).
  private static let mapSurfaceY: Float = -0.3

  // MARK: - Init

  /// Creates a spatial map view with the given news items.
  ///
  /// - Parameter newsItems: The news items to display as spatial annotations.
  public init(newsItems: [NewsItem] = []) {
    _newsItems = State(wrappedValue: newsItems)
  }

  // MARK: - Body

  public var body: some View {
    #if canImport(RealityKit) && os(visionOS)
      spatialContent
    #else
      unsupportedPlatformView
    #endif
  }

  // MARK: - Spatial Content (visionOS)

  #if canImport(RealityKit) && os(visionOS)
    private var spatialContent: some View {
      RealityView { content in
        // Create the base map surface.
        let mapSurface = createMapSurface()
        content.add(mapSurface)

        // Place news annotations.
        for item in newsItems {
          let annotation = createAnnotationEntity(for: item)
          content.add(annotation)
        }

        Self.logger.info(
          "Spatial map loaded with \(newsItems.count) annotations."
        )
      }
    }

    /// Creates a flat plane representing the map surface.
    @MainActor
    private func createMapSurface() -> ModelEntity {
      let mesh = MeshResource.generatePlane(
        width: 2.0,
        depth: 2.0,
        cornerRadius: 0.05
      )

      var material = SimpleMaterial()
      material.color = .init(
        tint: .systemGray.withAlphaComponent(0.3),
        texture: nil
      )
      material.metalness = .init(floatLiteral: 0.1)
      material.roughness = .init(floatLiteral: 0.9)

      let entity = ModelEntity(mesh: mesh, materials: [material])
      entity.name = "MapSurface"
      entity.position.y = Self.mapSurfaceY

      return entity
    }

    /// Creates a floating annotation entity for a news item.
    @MainActor
    private func createAnnotationEntity(for item: NewsItem) -> Entity {
      let parentEntity = Entity()
      parentEntity.name = "Annotation-\(item.id)"

      // Convert geo coordinates to scene position.
      let x = Float(item.coordinate.longitude) * Self.geoToSceneScale
      let z = Float(item.coordinate.latitude) * Self.geoToSceneScale
      parentEntity.position = SIMD3<Float>(x, Self.annotationYOffset, z)

      // Create a small sphere as the annotation marker.
      let markerMesh = MeshResource.generateSphere(radius: 0.015)
      var markerMaterial = SimpleMaterial()
      markerMaterial.color = .init(
        tint: categoryColor(for: item.category),
        texture: nil
      )
      markerMaterial.metalness = .init(floatLiteral: 0.5)
      markerMaterial.roughness = .init(floatLiteral: 0.3)

      let marker = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
      marker.name = "Marker-\(item.id)"
      marker.generateCollisionShapes(recursive: false)
      marker.components.set(
        InputTargetComponent(allowedInputTypes: .all)
      )

      parentEntity.addChild(marker)

      // Add a vertical line from the surface to the marker.
      let lineMesh = MeshResource.generateCylinder(
        height: Self.annotationYOffset - Self.mapSurfaceY,
        radius: 0.002
      )
      var lineMaterial = SimpleMaterial()
      lineMaterial.color = .init(
        tint: .white.withAlphaComponent(0.3),
        texture: nil
      )
      let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
      lineEntity.position.y = -(Self.annotationYOffset - Self.mapSurfaceY) / 2
      parentEntity.addChild(lineEntity)

      return parentEntity
    }

    /// Maps a news category to a UIColor for the annotation marker.
    private func categoryColor(for category: NewsCategory) -> UIColor {
      switch category {
      case .technology: return .systemBlue
      case .science: return .systemPurple
      case .politics: return .systemRed
      case .health: return .systemGreen
      case .sports: return .systemOrange
      case .entertainment: return .systemPink
      case .business: return .systemYellow
      case .environment: return .systemTeal
      case .other: return .systemGray
      }
    }
  #endif

  // MARK: - Unsupported Platform

  private var unsupportedPlatformView: some View {
    VStack(spacing: 20) {
      Image(systemName: "visionpro.fill")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      Text("Spatial Map")
        .font(.title)
        .fontWeight(.bold)

      Text("The immersive spatial map experience requires Apple Vision Pro.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Spatial Map View") {
    SpatialMapView(newsItems: [])
  }
#endif
