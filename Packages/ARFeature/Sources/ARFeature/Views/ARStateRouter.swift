//
//  ARStateRouter.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import SwiftUI

// MARK: - ARStateRouter

/// Routes the AR viewer between its four lifecycle states.
///
/// Observes ``ARNewsViewModel/modelState`` and renders the
/// corresponding subview:
///
/// | State      | View                    |
/// |------------|-------------------------|
/// | `.idle`    | Transparent placeholder |
/// | `.loading` | ``ARLoadingOverlay``    |
/// | `.loaded`  | ``ARPlatformRouter``    |
/// | `.failed`  | ``ARErrorOverlay``      |
///
/// ## Design Decision
///
/// Extracted from ``ARNewsView`` so that the composition root only
/// owns lifecycle (`onAppear`/`onDisappear`) and overlay toggling.
/// The state machine is independently testable and previewable.
struct ARStateRouter: View {

  // MARK: - Properties

  let viewModel: ARNewsViewModel

  // MARK: - Body

  var body: some View {
    switch viewModel.modelState {
    case .idle:
      Color.clear

    case .loading:
      ARLoadingOverlay(headline: viewModel.newsItem.headline)

    case .loaded:
      ARPlatformRouter(viewModel: viewModel)

    case .failed(let message):
      ARErrorOverlay(
        message: message,
        onRetry: {
          viewModel.reset()
          viewModel.loadModel()
        }
      )
    }
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("State Router — Loading") {
    let item = NewsItem(
      id: "preview-router-1",
      headline: "Quantum Breakthrough Achieves 1000 Qubit Milestone",
      summary: "Researchers demonstrate a stable processor.",
      source: "Nature",
      category: .science,
      coordinate: GeoCoordinate(latitude: 51.508, longitude: -0.076)!,
      publishedAt: Date()
    )
    let vm = ARNewsViewModel(newsItem: item)
    ARStateRouter(viewModel: vm)
  }
#endif
