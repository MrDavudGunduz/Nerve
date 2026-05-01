//
//  RealityKitARContentView.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

#if canImport(RealityKit) && os(iOS)

  import Core
  import RealityKit
  import SwiftUI

  // MARK: - RealityKitARContentView

  /// Camera-based AR content view for iOS 18+.
  ///
  /// Uses `RealityView` with horizontal plane detection via
  /// `AnchorEntity` to place a USDZ model in the real world.
  /// Supports drag, pinch-to-scale, and rotation gestures via
  /// the shared ``EntityGestureHandlers``.
  ///
  /// ## Availability
  ///
  /// Isolated in a separate file with `@available(iOS 18.0, *)`
  /// to prevent the requirement from propagating up to ``ARNewsView``,
  /// which must support iOS 17+.
  ///
  /// ## Entity Setup
  ///
  /// ```
  /// AnchorEntity (.plane .horizontal)
  ///   └── ModelEntity (USDZ)
  ///         ├── normalized scale (fit to targetSize)
  ///         ├── collision shapes (recursive)
  ///         └── InputTargetComponent (.all)
  /// ```
  @available(iOS 18.0, *)
  struct RealityKitARContentView: View {

    // MARK: - Properties

    let viewModel: ARNewsViewModel
    @State private var gestureState = EntityGestureState()

    // MARK: - Body

    var body: some View {
      RealityView { content in
        let anchor = makeAnchor()

        if let modelURL = viewModel.modelURL {
          await loadAndAttach(url: modelURL, to: anchor)
        } else {
          let placeholder = PlaceholderEntity.create()
          anchor.addChild(placeholder)
        }

        content.add(anchor)
      } update: { _ in
        // Respond to state changes if needed.
      }
      .gesture(dragGesture)
      .gesture(magnifyGesture)
      .gesture(rotateGesture)
      .ignoresSafeArea()
    }

    // MARK: - Scene Construction

    /// Creates a horizontal plane anchor for surface detection.
    private func makeAnchor() -> AnchorEntity {
      AnchorEntity(.plane(
        .horizontal,
        classification: .any,
        minimumBounds: ARContentConstants.planeMinBounds
      ))
    }

    /// Loads a USDZ model and attaches it to the given anchor.
    ///
    /// - Parameters:
    ///   - url: The local file URL of the USDZ model.
    ///   - anchor: The anchor entity to attach the model to.
    private func loadAndAttach(url: URL, to anchor: AnchorEntity) async {
      do {
        let entity = try await ModelEntity(contentsOf: url)
        entity.name = "ARNewsModel"

        normalizeScale(of: entity)
        entity.position.y = ARNewsConfiguration.surfacePlacementOffset
        enableInteraction(on: entity)

        anchor.addChild(entity)
      } catch {
        ARNewsViewLog.logger.error(
          "Failed to load RealityKit entity: \(error.localizedDescription)"
        )
      }
    }

    /// Scales the entity uniformly so its largest dimension equals ``ARContentConstants/targetModelSize``.
    private func normalizeScale(of entity: ModelEntity) {
      let bounds = entity.visualBounds(relativeTo: nil)
      let maxDimension = max(
        bounds.extents.x,
        max(bounds.extents.y, bounds.extents.z)
      )

      guard maxDimension > 0 else { return }

      let scaleFactor = ARContentConstants.targetModelSize / maxDimension
      entity.scale = SIMD3<Float>(repeating: scaleFactor)
    }

    /// Enables collision detection and gesture input on the entity.
    private func enableInteraction(on entity: ModelEntity) {
      entity.generateCollisionShapes(recursive: true)
      entity.components.set(
        InputTargetComponent(allowedInputTypes: .all)
      )
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

    private var rotateGesture: some Gesture {
      RotateGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          EntityGestureHandlers.handleRotation(
            angle: value.rotation,
            on: value.entity,
            state: gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
        }
    }
  }

  // MARK: - ARContentConstants

  /// Layout and physics constants for RealityKit content views.
  ///
  /// Shared between ``RealityKitARContentView`` and
  /// ``RealityKitSpatialContentView`` to keep values consistent
  /// across platforms.
  enum ARContentConstants {

    /// Minimum plane detection bounds (meters) for anchor placement.
    static let planeMinBounds: SIMD2<Float> = [0.2, 0.2]

    /// Target size (meters) to normalize the model's largest dimension.
    static let targetModelSize: Float = 0.3
  }

#endif
