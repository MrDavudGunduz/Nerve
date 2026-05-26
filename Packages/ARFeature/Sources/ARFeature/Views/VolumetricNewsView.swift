//
//  VolumetricNewsView.swift
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

// MARK: - VolumetricNewsView

/// A volumetric window view for displaying 3D news models on visionOS.
///
/// Renders a USDZ model inside a volumetric `WindowGroup` that extends
/// into the user's physical space. The model floats in 3D with spatial
/// lighting, supports gaze + pinch interaction, and plays spatial audio
/// cues on interaction events.
///
/// ## Features
///
/// - **Entity lifecycle management** — Tracks and tears down entities
///   to prevent VRAM leaks via ``EntityLifecycleManager``.
/// - **Idle rotation animation** — Model slowly rotates on Y-axis
///   for visual appeal when not being manipulated.
/// - **Spatial audio** — Plays attachment, detachment, and interaction
///   sounds via ``SpatialAudioEngine``.
/// - **Glassmorphism overlay card** — Floating headline + credibility badge
///   via ``AROverlayCard``.
/// - **Gesture support** — Drag, pinch-to-scale, and rotation gestures.
///
/// ## Usage
///
/// Register as a separate `WindowGroup` in `NerveApp`:
///
/// ```swift
/// WindowGroup(id: "news-3d-viewer") {
///   VolumetricNewsView()
/// }
/// .windowStyle(.volumetric)
/// .defaultSize(width: 0.5, height: 0.5, depth: 0.5, in: .meters)
/// ```
///
/// ## Architecture
///
/// - Reads the active ``NewsItem`` from the environment or a shared state.
/// - Uses ``ARAssetManager`` for model resolution.
/// - Configures the entity with ``ARNewsConfiguration/volumetricModelScale``.
public struct VolumetricNewsView: View {

  // MARK: - Properties

  @State private var viewModel: ARNewsViewModel?

  /// The news item to display, passed via environment or binding.
  @State private var newsItem: NewsItem?

  /// Whether the info overlay card is visible.
  @State private var showOverlayCard = true

  /// Controls the idle rotation animation.
  @State private var isIdleRotating = true

  #if canImport(RealityKit)
    /// Entity lifecycle tracker for VRAM-safe teardown.
    @State private var lifecycleManager = EntityLifecycleManager()
  #endif

  private static let logger = Logger(
    subsystem: LogSubsystem.arFeature,
    category: "VolumetricNewsView"
  )

  // MARK: - Init

  /// Creates a volumetric news view.
  ///
  /// - Parameter newsItem: The news item to render. Pass `nil` to show
  ///   a placeholder until a news item is provided.
  public init(newsItem: NewsItem? = nil) {
    _newsItem = State(wrappedValue: newsItem)
  }

  // MARK: - Body

  public var body: some View {
    Group {
      if let viewModel {
        volumetricContent(viewModel: viewModel)
      } else {
        emptyState
      }
    }
    .onChange(of: newsItem) { _, newItem in
      guard let newItem else {
        viewModel = nil
        return
      }
      viewModel = ARNewsViewModel(newsItem: newItem)
      viewModel?.loadModel()
    }
    .onAppear {
      if let newsItem, viewModel == nil {
        viewModel = ARNewsViewModel(newsItem: newsItem)
        viewModel?.loadModel()
      }
      #if os(visionOS)
        SpatialAudioEngine.initialize()
      #endif
    }
    .onDisappear {
      #if canImport(RealityKit)
        lifecycleManager.teardownAll()
      #endif
      #if os(visionOS)
        SpatialAudioEngine.playModelDetach()
      #endif
    }
  }

  // MARK: - Volumetric Content

  @ViewBuilder
  private func volumetricContent(viewModel: ARNewsViewModel) -> some View {
    switch viewModel.modelState {
    case .idle:
      emptyState

    case .loading:
      loadingState

    case .loaded:
      #if canImport(RealityKit) && os(visionOS)
        volumetricRealityView(viewModel: viewModel)
      #else
        ModelViewerView(
          newsItem: viewModel.newsItem,
          modelURL: viewModel.modelURL
        )
      #endif

    case .failed(let message):
      errorState(message: message)
    }
  }

  // MARK: - Loading State

  private var loadingState: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.5)
        .tint(.white)

      Text("Loading 3D Model…")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Preparing spatial content")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading 3D model")
  }

  // MARK: - Error State

  private func errorState(message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 40))
        .foregroundStyle(.orange)
        .symbolEffect(.pulse)

      Text("Model Unavailable")
        .font(.title3)
        .fontWeight(.bold)

      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if let viewModel {
        Button {
          viewModel.reset()
          viewModel.loadModel()
        } label: {
          Label("Retry", systemImage: "arrow.clockwise")
            .font(.callout)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
      }
    }
    .padding()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Model loading failed: \(message)")
  }

  // MARK: - RealityKit Volumetric (visionOS only)

  #if canImport(RealityKit) && os(visionOS)
    @State private var gestureState = EntityGestureState()

    private func volumetricRealityView(viewModel: ARNewsViewModel) -> some View {
      ZStack {
        // 3D content
        RealityView { content in
          if let modelURL = viewModel.modelURL {
            do {
              let entity = try await ModelEntity(contentsOf: modelURL)
              entity.name = "VolumetricNewsModel"

              // Scale for volumetric context.
              entity.scale = SIMD3<Float>(
                repeating: ARNewsConfiguration.volumetricModelScale
              )

              // Center in the volumetric window.
              entity.position = .zero

              // Enable gestures.
              entity.generateCollisionShapes(recursive: true)
              entity.components.set(
                InputTargetComponent(allowedInputTypes: .all)
              )

              // Add ground shadow.
              entity.components.set(GroundingShadowComponent(castsShadow: true))

              // Track for lifecycle management.
              lifecycleManager.track(entity)

              content.add(entity)

              // Play entrance animation.
              await EntityAnimations.playEntrance(on: entity, targetY: 0)

              // Start idle hover bob.
              EntityAnimations.startHoverBob(on: entity, amplitude: 0.003, duration: 3.0)

              // Spatial audio: model attached.
              SpatialAudioEngine.playModelAttach(at: entity.position)

              Self.logger.info("Volumetric model loaded and animated successfully.")
            } catch {
              Self.logger.error(
                "Failed to load volumetric entity: \(error.localizedDescription)"
              )
            }
          }
        }
        .gesture(dragGesture)
        .gesture(magnifyGesture)
        .gesture(rotateGesture)

        // Overlay card
        if showOverlayCard, let newsItem = viewModel.newsItem as NewsItem? {
          VStack {
            Spacer()

            AROverlayCard(
              newsItem: newsItem,
              onDismiss: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                  showOverlayCard = false
                }
              }
            )
            .padding(.bottom, 20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          }
        }

        // Toggle overlay button
        if !showOverlayCard {
          VStack {
            HStack {
              Spacer()
              Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                  showOverlayCard = true
                }
                SpatialAudioEngine.playAnnotationSelect()
              } label: {
                Image(systemName: "info.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.white)
                  .padding(12)
                  .background(.ultraThinMaterial)
                  .clipShape(Circle())
              }
              .buttonStyle(.plain)
              .padding()
              .accessibilityLabel("Show news information")
            }
            Spacer()
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: showOverlayCard)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
      DragGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          isIdleRotating = false
          EntityGestureHandlers.handleDrag(
            translation: value.translation,
            on: value.entity,
            state: &gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
          // Resume idle rotation after gesture.
          Task {
            try? await Task.sleep(for: .seconds(2.0))
            isIdleRotating = true
          }
        }
    }

    private var magnifyGesture: some Gesture {
      MagnifyGesture()
        .targetedToAnyEntity()
        .onChanged { value in
          isIdleRotating = false
          EntityGestureHandlers.handleScale(
            magnification: value.magnification,
            on: value.entity,
            state: &gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
          SpatialAudioEngine.playAnnotationSelect(at: value.entity.position)
        }
    }

    private var rotateGesture: some Gesture {
      RotateGesture3D()
        .targetedToAnyEntity()
        .onChanged { value in
          isIdleRotating = false
          let angle = Angle(radians: value.rotation.angle.radians)
          EntityGestureHandlers.handleRotation(
            angle: angle,
            on: value.entity,
            state: &gestureState
          )
        }
        .onEnded { value in
          gestureState.captureBaseline(from: value.entity)
        }
    }
  #endif

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
        .symbolEffect(.pulse)

      Text("No 3D Content")
        .font(.title3)
        .foregroundStyle(.secondary)

      Text("Select an AR-eligible news story to view its 3D model.")
        .font(.body)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No 3D content available. Select an AR-eligible news story.")
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Volumetric News View") {
    let item = NewsItem(
      id: "preview-vol-1",
      headline: "SpaceX Starship Completes Full Orbital Flight",
      summary: "Starship achieves stable orbit and returns to launch pad.",
      source: "SpaceNews",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 28.5729, longitude: -80.6490)!,
      publishedAt: Date(),
      analysis: HeadlineAnalysis(
        clickbaitScore: 0.05,
        sentiment: .positive,
        confidence: 0.98
      )
    )
    VolumetricNewsView(newsItem: item)
  }
#endif
