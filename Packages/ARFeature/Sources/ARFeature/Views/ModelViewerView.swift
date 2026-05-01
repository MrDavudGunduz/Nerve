//
//  ModelViewerView.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import OSLog
import SwiftUI

#if canImport(SceneKit)
  import SceneKit
#endif

// MARK: - ModelViewerView

/// A 3D model viewer fallback for devices without AR capability.
///
/// Uses SceneKit to render USDZ models in a non-AR context.
/// This view is used on:
/// - **macOS** — no camera-based AR support.
/// - **iOS Simulator** — no ARKit hardware.
/// - **Older iOS devices** — without ARKit world tracking.
///
/// ## Features
///
/// - **Orbit camera** — drag to rotate the model.
/// - **Pinch to zoom** — adjusts the camera distance.
/// - **Auto-rotation** — slow rotation when idle.
/// - **Studio lighting** — three-point cinematic lighting setup.
///
/// ## Design Decision
///
/// SceneKit is chosen over RealityKit for the fallback because:
/// 1. SceneKit's `SCNView` works identically on iOS and macOS.
/// 2. `SCNView.allowsCameraControl` provides built-in orbit gestures.
/// 3. USDZ files load natively via `SCNScene(url:)`.
public struct ModelViewerView: View {

  // MARK: - Properties

  private let newsItem: NewsItem
  private let modelURL: URL?

  // MARK: - Init

  /// Creates a model viewer for the given news item.
  ///
  /// - Parameters:
  ///   - newsItem: The news item metadata for the overlay.
  ///   - modelURL: The local file URL of the USDZ model.
  public init(newsItem: NewsItem, modelURL: URL?) {
    self.newsItem = newsItem
    self.modelURL = modelURL
  }

  // MARK: - Body

  public var body: some View {
    ZStack {
      #if canImport(SceneKit)
        SceneKitContainer(modelURL: modelURL)
          .ignoresSafeArea()
      #else
        UnavailablePlaceholderView()
      #endif
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("3D model viewer for \(newsItem.headline)")
  }
}

// MARK: - ModelViewerLog

/// File-scoped, nonisolated logging namespace for the model viewer.
///
/// Exists solely to provide a logger that both `@MainActor`-isolated
/// views **and** nonisolated SceneKit helpers can call without
/// generating Swift 6 actor-isolation warnings.
enum ModelViewerLog {

  static let logger = Logger(
    subsystem: "com.davudgunduz.Nerve.ARFeature",
    category: "ModelViewerView"
  )
}

// MARK: - UnavailablePlaceholderView

/// Shown on platforms where SceneKit is not available.
///
/// In practice this is unreachable since SceneKit ships with every
/// Apple platform, but the guard keeps the compiler happy and provides
/// a graceful fallback if the import is ever stripped.
private struct UnavailablePlaceholderView: View {

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "cube.transparent.fill")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      Text("3D Preview")
        .font(.title2)
        .fontWeight(.bold)

      Text("3D model viewing is not available on this device.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black.opacity(0.05))
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Model Viewer — No Model") {
    let item = NewsItem(
      id: "preview-mv-1",
      headline: "Breakthrough in Quantum Computing Achieves 1000 Qubit Milestone",
      summary: "Researchers demonstrate stable 1000-qubit processor.",
      source: "Nature",
      category: .science,
      coordinate: GeoCoordinate(latitude: 51.508, longitude: -0.076)!,
      publishedAt: Date(),
      analysis: HeadlineAnalysis(
        clickbaitScore: 0.1,
        sentiment: .positive,
        confidence: 0.95
      )
    )
    ModelViewerView(newsItem: item, modelURL: nil)
  }
#endif
