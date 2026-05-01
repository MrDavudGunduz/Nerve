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
/// lighting and supports gaze + pinch interaction.
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

  private static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
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
    }
  }

  // MARK: - Volumetric Content

  @ViewBuilder
  private func volumetricContent(viewModel: ARNewsViewModel) -> some View {
    switch viewModel.modelState {
    case .idle:
      emptyState

    case .loading:
      VStack(spacing: 12) {
        ProgressView()
          .scaleEffect(1.3)
        Text("Loading 3D Model…")
          .font(.headline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

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
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 40))
          .foregroundStyle(.orange)
        Text("Model Unavailable")
          .font(.title3)
          .fontWeight(.bold)
        Text(message)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
    }
  }

  // MARK: - RealityKit Volumetric (visionOS only)

  #if canImport(RealityKit) && os(visionOS)
    @State private var gestureState = EntityGestureState()

    private func volumetricRealityView(viewModel: ARNewsViewModel) -> some View {
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

            content.add(entity)

            Self.logger.info("Volumetric model loaded successfully.")
          } catch {
            Self.logger.error(
              "Failed to load volumetric entity: \(error.localizedDescription)"
            )
          }
        }
      }
      .gesture(
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
      )
      .gesture(
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
      )
    }
  #endif

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "cube.transparent")
        .font(.system(size: 48))
        .foregroundStyle(.tertiary)
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
