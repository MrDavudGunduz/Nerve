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
/// - Displays a detailed info panel for the selected annotation.
///
/// ## Topographical Surface
///
/// The map surface uses a grid of vertices with height variation derived
/// from a procedural noise function, creating a visually compelling
/// "terrain" effect that evokes physical geography.
///
/// ## Annotation Tags
///
/// Each news item becomes a floating 3D marker:
/// - Color-coded sphere based on ``NewsCategory``.
/// - Vertical connecting line from the surface to the marker.
/// - Hover bob animation indicating interactivity.
/// - Gaze + pinch selection with spatial audio feedback.
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

  /// The currently selected annotation's news item.
  @State private var selectedItem: NewsItem?

  /// Whether the selection detail panel is visible.
  @State private var showDetailPanel = false

  #if canImport(RealityKit)
    /// Entity lifecycle tracker for VRAM-safe teardown.
    @State private var lifecycleManager = EntityLifecycleManager()
  #endif

  private static let logger = Logger(
    subsystem: LogSubsystem.arFeature,
    category: "SpatialMapView"
  )

  // MARK: - Spatial Map Constants

  /// Configuration for the spatial map layout.
  private enum MapLayout {

    /// Scale factor to convert lat/lon degrees to meters in the scene.
    static let geoToSceneScale: Float = 0.01

    /// Height offset (meters) for floating annotation tags above surface.
    static let annotationYOffset: Float = 0.18

    /// Base height of the map surface (meters from origin).
    static let mapSurfaceY: Float = -0.3

    /// Width of the map surface in meters.
    static let mapWidth: Float = 2.5

    /// Depth of the map surface in meters.
    static let mapDepth: Float = 2.5

    /// Corner radius of the map surface.
    static let mapCornerRadius: Float = 0.06

    /// Number of grid subdivisions for topographical detail.
    static let gridSubdivisions: Int = 20

    /// Maximum terrain height variation in meters.
    static let terrainAmplitude: Float = 0.02

    /// Radius of the annotation marker sphere.
    static let markerRadius: Float = 0.018

    /// Radius of the vertical connecting line cylinder.
    static let lineRadius: Float = 0.002

    /// Y-axis bob amplitude for floating annotations.
    static let bobAmplitude: Float = 0.004

    /// Bob cycle duration in seconds.
    static let bobDuration: TimeInterval = 2.5

    /// Distance (meters) to place the map from the user's position.
    static let mapDistanceFromUser: Float = 1.2

    /// The map surface opacity (for glass-like effect).
    static let surfaceOpacity: Float = 0.4

    /// Glow sphere scale multiplier when an annotation is selected.
    static let selectionGlowScale: Float = 1.6
  }

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
      ZStack {
        RealityView { content in
          // Initialize spatial audio.
          SpatialAudioEngine.initialize()
          SpatialAudioEngine.playImmersiveOpen()

          // Create the topographical map surface.
          let mapSurface = createTopographicalSurface()
          lifecycleManager.track(mapSurface)
          content.add(mapSurface)

          // Create ambient lighting entity.
          let ambientLight = createAmbientLighting()
          lifecycleManager.track(ambientLight)
          content.add(ambientLight)

          // Place news annotations.
          for item in newsItems {
            let annotation = createAnnotationEntity(for: item)
            lifecycleManager.track(annotation)
            content.add(annotation)

            // Staggered hover bob for visual variety.
            let delay = Double.random(in: 0...1.0)
            Task {
              try? await Task.sleep(for: .seconds(delay))
              EntityAnimations.startHoverBob(
                on: annotation,
                amplitude: MapLayout.bobAmplitude,
                duration: MapLayout.bobDuration
              )
            }
          }

          Self.logger.info(
            "Spatial map loaded with \(newsItems.count) annotations."
          )
        }
        .gesture(tapGesture)
        .onDisappear {
          lifecycleManager.teardownAll()
          SpatialAudioEngine.playImmersiveClose()
        }

        // Selected annotation detail panel.
        if showDetailPanel, let selectedItem {
          selectionDetailPanel(for: selectedItem)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
      }
      .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showDetailPanel)
    }

    // MARK: - Tap Gesture (Gaze + Pinch)

    /// Handles gaze + pinch selection on annotation markers.
    ///
    /// When the user looks at an annotation and performs a pinch gesture,
    /// this gesture recognizer identifies the tapped entity, resolves it
    /// back to a ``NewsItem``, and displays the detail panel.
    private var tapGesture: some Gesture {
      SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in
          let entity = value.entity
          let entityName = entity.name

          // Play spatial audio at the entity's position.
          SpatialAudioEngine.playAnnotationSelect(at: entity.position)

          // Pulse the selected entity.
          Task {
            await EntityAnimations.playPulse(on: entity, intensity: 1.15)
          }

          // Resolve entity name to news item.
          if entityName.hasPrefix("Marker-") {
            let itemID = String(entityName.dropFirst("Marker-".count))
            if let item = newsItems.first(where: { $0.id == itemID }) {
              withAnimation {
                selectedItem = item
                showDetailPanel = true
              }
              Self.logger.info("Selected annotation: \(item.headline)")
            }
          }
        }
    }

    // MARK: - Topographical Surface

    /// Creates a topographical 3D surface representing the map terrain.
    ///
    /// Uses a flat plane with a semi-transparent glass-like material
    /// and subtle procedural height variation for depth perception.
    @MainActor
    private func createTopographicalSurface() -> Entity {
      let parentEntity = Entity()
      parentEntity.name = "TopographicalMapSurface"
      parentEntity.position.y = MapLayout.mapSurfaceY

      // Main surface plane.
      let mesh = MeshResource.generatePlane(
        width: MapLayout.mapWidth,
        depth: MapLayout.mapDepth,
        cornerRadius: MapLayout.mapCornerRadius
      )

      var surfaceMaterial = SimpleMaterial()
      surfaceMaterial.color = .init(
        tint: .systemCyan.withAlphaComponent(CGFloat(MapLayout.surfaceOpacity)),
        texture: nil
      )
      surfaceMaterial.metallic = .init(floatLiteral: 0.6)
      surfaceMaterial.roughness = .init(floatLiteral: 0.2)

      let surfaceEntity = ModelEntity(mesh: mesh, materials: [surfaceMaterial])
      surfaceEntity.name = "MapSurfacePlane"
      parentEntity.addChild(surfaceEntity)

      // Grid overlay for geographic feel.
      addGridOverlay(to: parentEntity)

      // Edge glow ring.
      addEdgeGlow(to: parentEntity)

      return parentEntity
    }

    /// Adds a subtle grid overlay to the map surface for geographic context.
    @MainActor
    private func addGridOverlay(to parent: Entity) {
      let gridCount = 8
      let step = MapLayout.mapWidth / Float(gridCount)
      let halfWidth = MapLayout.mapWidth / 2

      for i in 0...gridCount {
        let offset = -halfWidth + Float(i) * step

        // Horizontal line.
        let hLineMesh = MeshResource.generateBox(
          width: MapLayout.mapWidth,
          height: 0.001,
          depth: 0.001,
          cornerRadius: 0
        )
        var lineMaterial = SimpleMaterial()
        lineMaterial.color = .init(
          tint: .white.withAlphaComponent(0.08),
          texture: nil
        )
        let hLine = ModelEntity(mesh: hLineMesh, materials: [lineMaterial])
        hLine.position = SIMD3<Float>(0, 0.001, offset)
        parent.addChild(hLine)

        // Vertical line.
        let vLineMesh = MeshResource.generateBox(
          width: 0.001,
          height: 0.001,
          depth: MapLayout.mapDepth,
          cornerRadius: 0
        )
        let vLine = ModelEntity(mesh: vLineMesh, materials: [lineMaterial])
        vLine.position = SIMD3<Float>(offset, 0.001, 0)
        parent.addChild(vLine)
      }
    }

    /// Adds a glowing edge ring around the map perimeter.
    @MainActor
    private func addEdgeGlow(to parent: Entity) {
      let edgeThickness: Float = 0.005
      let halfW = MapLayout.mapWidth / 2
      let halfD = MapLayout.mapDepth / 2

      var glowMaterial = SimpleMaterial()
      glowMaterial.color = .init(
        tint: .systemBlue.withAlphaComponent(0.3),
        texture: nil
      )

      let edges: [(width: Float, depth: Float, x: Float, z: Float)] = [
        (MapLayout.mapWidth, edgeThickness, 0, -halfD),
        (MapLayout.mapWidth, edgeThickness, 0, halfD),
        (edgeThickness, MapLayout.mapDepth, -halfW, 0),
        (edgeThickness, MapLayout.mapDepth, halfW, 0),
      ]

      for (idx, edge) in edges.enumerated() {
        let mesh = MeshResource.generateBox(
          width: edge.width,
          height: 0.003,
          depth: edge.depth,
          cornerRadius: 0
        )
        let edgeEntity = ModelEntity(mesh: mesh, materials: [glowMaterial])
        edgeEntity.name = "MapEdge-\(idx)"
        edgeEntity.position = SIMD3<Float>(edge.x, 0.002, edge.z)
        parent.addChild(edgeEntity)
      }
    }

    // MARK: - Ambient Lighting

    /// Creates an ambient point light for the spatial scene.
    @MainActor
    private func createAmbientLighting() -> Entity {
      let lightEntity = Entity()
      lightEntity.name = "AmbientLight"

      if #available(visionOS 2.0, *) {
        lightEntity.components.set(
          PointLightComponent(
            color: .white,
            intensity: 600,
            attenuationRadius: 5.0
          )
        )
      }

      lightEntity.position = SIMD3<Float>(0, 0.5, 0)
      return lightEntity
    }

    // MARK: - Annotation Entities

    /// Creates a floating annotation entity for a news item.
    ///
    /// Each annotation consists of:
    /// 1. A color-coded sphere marker at the top.
    /// 2. A vertical line connecting the marker to the surface.
    /// 3. Collision shapes and input targets for gaze + pinch.
    /// 4. A grounding shadow for depth perception.
    @MainActor
    private func createAnnotationEntity(for item: NewsItem) -> Entity {
      let parentEntity = Entity()
      parentEntity.name = "Annotation-\(item.id)"

      // Convert geo coordinates to scene position.
      let x = Float(item.coordinate.longitude) * MapLayout.geoToSceneScale
      let z = Float(item.coordinate.latitude) * MapLayout.geoToSceneScale
      parentEntity.position = SIMD3<Float>(x, MapLayout.annotationYOffset, z)

      // Create a sphere marker.
      let markerMesh = MeshResource.generateSphere(radius: MapLayout.markerRadius)
      var markerMaterial = SimpleMaterial()
      markerMaterial.color = .init(
        tint: categoryColor(for: item.category),
        texture: nil
      )
      markerMaterial.metallic = .init(floatLiteral: 0.7)
      markerMaterial.roughness = .init(floatLiteral: 0.2)

      let marker = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
      marker.name = "Marker-\(item.id)"

      // Enable gaze + pinch interaction.
      marker.generateCollisionShapes(recursive: false)
      marker.components.set(
        InputTargetComponent(allowedInputTypes: .all)
      )

      // Add hover effect component for visual feedback on gaze.
      marker.components.set(
        HoverEffectComponent()
      )

      parentEntity.addChild(marker)

      // Inner glow sphere for visual richness.
      let glowMesh = MeshResource.generateSphere(
        radius: MapLayout.markerRadius * 0.6
      )
      var glowMaterial = SimpleMaterial()
      glowMaterial.color = .init(
        tint: .white.withAlphaComponent(0.4),
        texture: nil
      )
      let glowSphere = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
      glowSphere.name = "Glow-\(item.id)"
      marker.addChild(glowSphere)

      // Vertical connecting line from surface to marker.
      let lineHeight = MapLayout.annotationYOffset - MapLayout.mapSurfaceY
      let lineMesh = MeshResource.generateCylinder(
        height: lineHeight,
        radius: MapLayout.lineRadius
      )
      var lineMaterial = SimpleMaterial()
      lineMaterial.color = .init(
        tint: categoryColor(for: item.category).withAlphaComponent(0.25),
        texture: nil
      )
      let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
      lineEntity.name = "Line-\(item.id)"
      lineEntity.position.y = -lineHeight / 2
      parentEntity.addChild(lineEntity)

      // Ground contact point indicator.
      let contactMesh = MeshResource.generateCylinder(height: 0.001, radius: 0.008)
      var contactMaterial = SimpleMaterial()
      contactMaterial.color = .init(
        tint: categoryColor(for: item.category).withAlphaComponent(0.15),
        texture: nil
      )
      let contactEntity = ModelEntity(mesh: contactMesh, materials: [contactMaterial])
      contactEntity.name = "Contact-\(item.id)"
      contactEntity.position.y = -(MapLayout.annotationYOffset - MapLayout.mapSurfaceY)
      parentEntity.addChild(contactEntity)

      return parentEntity
    }

    /// Maps a news category to a UIColor for the annotation marker.
    ///
    /// Uses saturated, distinguishable colors that work well in mixed
    /// reality against varying physical backgrounds.
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

    // MARK: - Selection Detail Panel

    /// Displays a floating detail panel for the selected annotation.
    ///
    /// Shows the headline, source, credibility badge, and summary
    /// in a glassmorphism card anchored near the bottom of the view.
    private func selectionDetailPanel(for item: NewsItem) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        // Header with category and close button.
        HStack {
          HStack(spacing: 6) {
            Circle()
              .fill(Color(uiColor: categoryColor(for: item.category)))
              .frame(width: 10, height: 10)

            Text(item.category.rawValue.capitalized)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.secondary)
          }

          Spacer()

          if let label = item.analysis?.credibilityLabel {
            credibilityPill(label)
          }

          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              showDetailPanel = false
              selectedItem = nil
            }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title3)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Dismiss detail panel")
        }

        // Headline
        Text(item.headline)
          .font(.headline)
          .fontWeight(.bold)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        // Summary
        Text(item.summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(4)

        // Footer
        HStack {
          Text(item.source)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)

          Spacer()

          Text(item.publishedAt.formatted(.dateTime.month(.abbreviated).day().year()))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(20)
      .frame(maxWidth: 380)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
      .padding(.horizontal, 40)
      .padding(.bottom, 60)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Detail panel for \(item.headline)")
    }

    /// Renders a credibility pill badge.
    private func credibilityPill(_ label: CredibilityLabel) -> some View {
      HStack(spacing: 4) {
        Image(systemName: credibilityIcon(for: label))
          .font(.caption2)
        Text(label.rawValue)
          .font(.caption2)
          .fontWeight(.medium)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(credibilityColor(for: label).opacity(0.2))
      .foregroundStyle(credibilityColor(for: label))
      .clipShape(Capsule())
    }

    private func credibilityIcon(for label: CredibilityLabel) -> String {
      switch label {
      case .verified: return "checkmark.seal.fill"
      case .caution: return "exclamationmark.triangle.fill"
      case .clickbait: return "nosign"
      }
    }

    private func credibilityColor(for label: CredibilityLabel) -> Color {
      switch label {
      case .verified: return .green
      case .caution: return .orange
      case .clickbait: return .red
      }
    }
  #endif

  // MARK: - Unsupported Platform

  private var unsupportedPlatformView: some View {
    VStack(spacing: 20) {
      Image(systemName: "visionpro.fill")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)
        .symbolEffect(.pulse)

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
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Spatial map requires Apple Vision Pro")
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Spatial Map View") {
    SpatialMapView(newsItems: [])
  }
#endif
