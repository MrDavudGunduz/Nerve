//
//  AROverlayToggle.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Core
import SwiftUI

// MARK: - AROverlayToggle

/// Manages the dismissible overlay card and its toggle button.
///
/// When the overlay is visible, shows an ``AROverlayCard`` pinned
/// to the bottom of the viewport with a spring transition.
/// When dismissed, shows a floating info button in the bottom-right
/// corner to bring it back.
///
/// ## Animation
///
/// - **Dismiss:** `.easeOut(duration: 0.3)` — fast, decisive.
/// - **Reveal:** `.easeIn(duration: 0.3)` — gentle re-entrance.
/// - **Card entry:** `.spring(dampingFraction: 0.8)` — natural settle.
///
/// ## Design Decision
///
/// Extracted from ``ARNewsView`` so the composition root body
/// remains a simple `ZStack { router; toggle }` with no animation
/// or overlay logic inline.
struct AROverlayToggle: View {

  // MARK: - Properties

  @Bindable var viewModel: ARNewsViewModel

  // MARK: - Body

  var body: some View {
    ZStack(alignment: .bottom) {
      // Transparent hit target — does not consume taps.
      Color.clear

      if viewModel.isOverlayVisible {
        overlayCard
      } else {
        infoButton
      }
    }
  }

  // MARK: - Overlay Card

  private var overlayCard: some View {
    VStack {
      Spacer()

      AROverlayCard(
        newsItem: viewModel.newsItem,
        onDismiss: {
          withAnimation(.easeOut(duration: AROverlayToggleConstants.dismissDuration)) {
            viewModel.isOverlayVisible = false
          }
        }
      )
      .padding(.horizontal, AROverlayToggleConstants.horizontalPadding)
      .padding(.bottom, AROverlayToggleConstants.bottomPadding)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    .animation(
      .spring(dampingFraction: AROverlayToggleConstants.springDamping),
      value: viewModel.isOverlayVisible
    )
  }

  // MARK: - Info Button

  private var infoButton: some View {
    VStack {
      Spacer()

      HStack {
        Spacer()

        Button {
          withAnimation(.easeIn(duration: AROverlayToggleConstants.revealDuration)) {
            viewModel.isOverlayVisible = true
          }
        } label: {
          Image(systemName: "info.circle.fill")
            .font(.title2)
            .padding(AROverlayToggleConstants.buttonInset)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
        }
        .padding(AROverlayToggleConstants.buttonEdgePadding)
        .accessibilityLabel("Show news information")
        .accessibilityHint("Displays the headline, source, and credibility badge")
      }
    }
  }
}

// MARK: - AROverlayToggleConstants

/// Layout and animation constants for ``AROverlayToggle``.
///
/// Centralizes magic numbers so the toggle's visual behavior
/// can be tuned without touching view code.
private enum AROverlayToggleConstants {

  /// Duration (seconds) of the card dismiss animation.
  static let dismissDuration: TimeInterval = 0.3

  /// Duration (seconds) of the card reveal animation.
  static let revealDuration: TimeInterval = 0.3

  /// Spring damping ratio for the card entrance.
  static let springDamping: Double = 0.8

  /// Horizontal padding around the overlay card (points).
  static let horizontalPadding: CGFloat = 20

  /// Bottom padding below the overlay card (points).
  static let bottomPadding: CGFloat = 40

  /// Inset padding inside the info button circle (points).
  static let buttonInset: CGFloat = 12

  /// Edge padding around the info button (points).
  static let buttonEdgePadding: CGFloat = 20
}

// MARK: - Preview

#if DEBUG
  #Preview("Overlay Toggle — Visible") {
    let item = NewsItem(
      id: "preview-toggle-1",
      headline: "Apple Unveils Vision Pro 2 with Neural Display",
      summary: "Next generation spatial computing.",
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
    AROverlayToggle(viewModel: ARNewsViewModel(newsItem: item))
      .background(.black)
  }
#endif
