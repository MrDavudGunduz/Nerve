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
  /// ## Production Features
  ///
  /// - **Coaching overlay**: Guides the user to scan a horizontal surface.
  /// - **Tracking quality banner**: Shows tracking status feedback.
  /// - **Entrance animation**: Spring-based drop-in when the model is placed.
  /// - **Haptic feedback**: Tactile confirmation on placement and gestures.
  /// - **Surface detection**: ARKit plane detection with visual anchoring.
  ///
  /// ## Availability
  ///
  /// Isolated in a separate file with `@available(iOS 18.0, *)`
  /// to prevent the requirement from propagating up to ``ARNewsView``,
  /// which must support iOS 17+.
  ///
  /// ## Entity Hierarchy
  ///
  /// ```
  /// AnchorEntity (.plane .horizontal)
  ///   └── ModelEntity (USDZ)
  ///         ├── normalized scale (fit to targetSize)
  ///         ├── collision shapes (recursive)
  ///         ├── InputTargetComponent (.all)
  ///         └── entrance animation (spring drop-in)
  /// ```
  @available(iOS 18.0, *)
  struct RealityKitARContentView: View {

    // MARK: - Properties

    @Bindable var viewModel: ARNewsViewModel
    @State private var gestureState = EntityGestureState()
    @State private var placedEntity: ModelEntity?
    @State private var hasPerformedEntrance = false

    // MARK: - Body

    var body: some View {
      ZStack {
        // RealityKit AR scene.
        realityContent
          .ignoresSafeArea()

        // Coaching overlay — shown during surface scanning.
        if viewModel.showCoaching {
          ARCoachingOverlay(
            state: viewModel.coachingState,
            onSkip: {
              viewModel.skipCoaching()
            }
          )
          .transition(.opacity)
          .zIndex(10)
        }

        // Tracking quality banner.
        VStack {
          if viewModel.viewerMode == .augmentedReality
            && viewModel.placementState.isInteractive
          {
            ARTrackingBanner(quality: viewModel.trackingQuality)
              .padding(.top, 8)
          }
          Spacer()
        }
        .zIndex(5)
      }
      .animation(.easeInOut(duration: 0.3), value: viewModel.showCoaching)
      .animation(.spring(dampingFraction: 0.8), value: viewModel.placementState)
    }

    // MARK: - RealityView Content

    private var realityContent: some View {
      RealityView { content in
        let anchor = makeAnchor()

        if let modelURL = viewModel.modelURL {
          await loadAndAttach(url: modelURL, to: anchor)
        } else {
          let placeholder = PlaceholderEntity.create()
          anchor.addChild(placeholder)
        }

        content.add(anchor)

        // Notify ViewModel that a surface has been detected
        // once the anchor activates (plane detected by ARKit).
        Task { @MainActor in
          // Give ARKit time to detect the plane anchor.
          try? await Task.sleep(for: .seconds(1.5))
          if viewModel.placementState == .coaching {
            viewModel.onSurfaceDetected()
          }
        }
      } update: { _ in
        // Trigger entrance animation when placement state changes.
        if viewModel.placementState == .animatingEntrance,
          !hasPerformedEntrance,
          let entity = placedEntity
        {
          hasPerformedEntrance = true
          Task {
            await EntityAnimations.playEntrance(
              on: entity,
              targetY: ARNewsConfiguration.surfacePlacementOffset
            )
            viewModel.completeEntityPlacement()
          }
        }
      }
      .gesture(dragGesture)
      .gesture(magnifyGesture)
      .gesture(rotateGesture)
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

        // Store reference for entrance animation.
        await MainActor.run {
          self.placedEntity = entity
        }
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
          guard viewModel.placementState.isInteractive else { return }
          EntityGestureHandlers.handleDrag(
            translation: value.translation,
            on: value.entity,
            state: &gestureState
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
          guard viewModel.placementState.isInteractive else { return }
          EntityGestureHandlers.handleScale(
            magnification: value.magnification,
            on: value.entity,
            state: &gestureState
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
          guard viewModel.placementState.isInteractive else { return }
          EntityGestureHandlers.handleRotation(
            angle: value.rotation,
            on: value.entity,
            state: &gestureState
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
