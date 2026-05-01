//
//  ARPlatformRouter.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import SwiftUI

#if canImport(RealityKit)
  import RealityKit
#endif

// MARK: - ARPlatformRouter

/// Selects the platform-appropriate 3D rendering view.
///
/// This router encapsulates all `#if os(...)` and `@available`
/// branching in one place, keeping the rest of the view hierarchy
/// free of conditional compilation noise.
///
/// ## Decision Tree
///
/// ```
/// ARPlatformRouter
///   ├── .augmentedReality
///   │     ├── iOS 18+  →  RealityKitARContentView
///   │     └── iOS 17   →  ModelViewerView (SceneKit)
///   ├── .spatial
///   │     ├── visionOS →  RealityKitSpatialContentView
///   │     └── other    →  ModelViewerView (SceneKit)
///   └── .modelViewer   →  ModelViewerView (SceneKit)
/// ```
struct ARPlatformRouter: View {

  // MARK: - Properties

  let viewModel: ARNewsViewModel

  // MARK: - Body

  var body: some View {
    switch viewModel.viewerMode {
    case .augmentedReality:
      augmentedRealityContent

    case .spatial:
      spatialContent

    case .modelViewer:
      sceneKitFallback
    }
  }

  // MARK: - Augmented Reality (iOS)

  @ViewBuilder
  private var augmentedRealityContent: some View {
    #if os(iOS)
      if #available(iOS 18.0, *) {
        RealityKitARContentView(viewModel: viewModel)
      } else {
        sceneKitFallback
      }
    #else
      sceneKitFallback
    #endif
  }

  // MARK: - Spatial (visionOS)

  @ViewBuilder
  private var spatialContent: some View {
    #if os(visionOS)
      RealityKitSpatialContentView(viewModel: viewModel)
    #else
      sceneKitFallback
    #endif
  }

  // MARK: - SceneKit Fallback

  private var sceneKitFallback: some View {
    ModelViewerView(
      newsItem: viewModel.newsItem,
      modelURL: viewModel.modelURL
    )
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Platform Router — Model Viewer") {
    let item = NewsItem(
      id: "preview-platform-1",
      headline: "Apple M5 Ultra Benchmarks Revealed",
      summary: "The new chip doubles machine learning performance.",
      source: "AnandTech",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date()
    )
    ARPlatformRouter(viewModel: ARNewsViewModel(newsItem: item))
  }
#endif
