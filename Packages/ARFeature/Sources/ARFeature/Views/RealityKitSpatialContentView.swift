//
//  RealityKitSpatialContentView.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(RealityKit) && os(visionOS)

  import Core
  import RealityKit
  import SwiftUI

  // MARK: - RealityKitSpatialContentView

  /// Spatial content view for visionOS standard windows.
  ///
  /// Renders a USDZ model in front of the user at a configurable
  /// distance with drag and pinch-to-scale gestures.
  ///
  /// ## Entity Setup
  ///
  /// ```
  /// RealityView content
  ///   └── ModelEntity (USDZ)
  ///         ├── position [0, 0, -defaultModelDistance]
  ///         ├── scale (volumetricModelScale)
  ///         ├── collision shapes (recursive)
  ///         └── InputTargetComponent (.all)
  /// ```
  struct RealityKitSpatialContentView: View {

    // MARK: - Properties

    let viewModel: ARNewsViewModel
    @State private var gestureState = EntityGestureState()

    // MARK: - Body

    var body: some View {
      RealityView { content in
        guard let modelURL = viewModel.modelURL else { return }
        await loadAndPlace(url: modelURL, in: content)
      }
      .gesture(dragGesture)
      .gesture(magnifyGesture)
    }

    // MARK: - Scene Construction

    /// Loads a USDZ model and places it in the spatial content.
    ///
    /// - Parameters:
    ///   - url: The local file URL of the USDZ model.
    ///   - content: The RealityView content to add the entity to.
    private func loadAndPlace(url: URL, in content: RealityViewContent) async {
      do {
        let entity = try await ModelEntity(contentsOf: url)
        entity.name = "SpatialNewsModel"

        // Position in front of the user.
        entity.position = [0, 0, -ARNewsConfiguration.defaultModelDistance]

        // Scale for spatial context.
        entity.scale = SIMD3<Float>(
          repeating: ARNewsConfiguration.volumetricModelScale
        )

        // Enable gestures.
        entity.generateCollisionShapes(recursive: true)
        entity.components.set(
          InputTargetComponent(allowedInputTypes: .all)
        )

        content.add(entity)
      } catch {
        ARNewsViewLog.logger.error(
          "Failed to load spatial entity: \(error.localizedDescription)"
        )
      }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
      DragGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          EntityGestureHandlers.handleDrag(
            translation: value.translation,
            on: value.entity,
            state: gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
        }
    }

    private var magnifyGesture: some Gesture {
      MagnifyGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          EntityGestureHandlers.handleScale(
            magnification: value.magnification,
            on: value.entity,
            state: gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
        }
    }
  }

#endif
