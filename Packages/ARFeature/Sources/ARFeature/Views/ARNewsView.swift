//
//  ARNewsView.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import OSLog
import SwiftUI

// MARK: - ARNewsView

/// The primary AR/3D news viewer that adapts to device capabilities.
///
/// ## Platform Behavior
///
/// - **iOS 18+ with ARKit:** Full camera-based AR with RealityView,
///   plane detection, gesture-based manipulation (drag, scale, rotate),
///   and a floating overlay card.
///
/// - **iOS 17:** Falls back to ``ModelViewerView`` using SceneKit.
///
/// - **visionOS:** RealityKit rendering in a standard window.
///   Volumetric and immersive modes are launched separately.
///
/// - **macOS / Simulator:** Falls back to ``ModelViewerView`` using
///   SceneKit for 3D model viewing without camera AR.
///
/// ## Architecture
///
/// `ARNewsView` acts purely as a **composition root**. It owns the
/// ``ARNewsViewModel`` state and wires together independent subviews:
///
/// ```
/// ARNewsView (composition root)
///   ├── ARStateRouter       → loading / loaded / error state machine
///   │     ├── ARLoadingOverlay
///   │     ├── ARErrorOverlay
///   │     └── ARPlatformRouter → platform-adaptive 3D content
///   └── AROverlayToggle     → card + info button
/// ```
///
/// Each subview is a standalone `View` that can be previewed, tested,
/// and iterated on in isolation.
///
/// ```swift
/// ARNewsView(newsItem: item)
///   .navigationTitle("AR Preview")
/// ```
public struct ARNewsView: View {

  // MARK: - Properties

  @State private var viewModel: ARNewsViewModel

  // MARK: - Init

  /// Creates an AR news view for the given news item.
  ///
  /// - Parameter newsItem: The news item to render in AR.
  public init(newsItem: NewsItem) {
    _viewModel = State(
      wrappedValue: ARNewsViewModel(newsItem: newsItem)
    )
  }

  /// Creates an AR news view with an injected view model (for testing).
  ///
  /// - Parameter viewModel: A pre-configured view model.
  public init(viewModel: ARNewsViewModel) {
    _viewModel = State(wrappedValue: viewModel)
  }

  // MARK: - Body

  public var body: some View {
    ZStack {
      // Model state machine → loading / loaded / error
      ARStateRouter(viewModel: viewModel)

      // Overlay card + info toggle
      AROverlayToggle(viewModel: viewModel)
    }
    .onAppear {
      viewModel.loadModel()
    }
    .onDisappear {
      viewModel.cancelLoading()
    }
  }
}

// MARK: - ARNewsViewLog

/// Nonisolated logging namespace for the AR news view pipeline.
///
/// Provides a logger that both `@MainActor`-isolated SwiftUI views
/// and nonisolated `#if canImport(RealityKit)` blocks can call
/// without crossing actor-isolation boundaries in Swift 6.
enum ARNewsViewLog {

  static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ARNewsView"
  )
}

// MARK: - Preview

#if DEBUG
  #Preview("AR News View") {
    let item = NewsItem(
      id: "preview-ar-1",
      headline: "Apple Unveils Vision Pro 2 with Neural Display",
      summary: "The next generation spatial computing device features advanced neural rendering.",
      source: "TechCrunch",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date(),
      analysis: HeadlineAnalysis(
        clickbaitScore: 0.15,
        sentiment: .positive,
        confidence: 0.92
      )
    )
    ARNewsView(newsItem: item)
  }
#endif
