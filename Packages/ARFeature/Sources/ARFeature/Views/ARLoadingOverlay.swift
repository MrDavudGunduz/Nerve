//
//  ARLoadingOverlay.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import SwiftUI

// MARK: - ARLoadingOverlay

/// A full-screen loading state overlay for the AR viewer.
///
/// Displays a centered progress spinner, a static "Loading 3D Model…"
/// label, and the news headline for context. Uses a semi-transparent
/// black scrim so the underlying camera/scene remains partially visible.
///
/// ## Accessibility
///
/// Elements are combined into a single VoiceOver group with a
/// descriptive label that includes the headline text.
struct ARLoadingOverlay: View {

  // MARK: - Properties

  /// The news headline shown below the spinner for context.
  let headline: String

  // MARK: - Body

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)
        .ignoresSafeArea()

      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.5)
          .tint(.white)

        Text("Loading 3D Model…")
          .font(.headline)
          .foregroundStyle(.white)

        Text(headline)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .padding(.horizontal, 40)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading 3D model for \(headline)")
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Loading Overlay") {
    ARLoadingOverlay(
      headline: "Apple Unveils Vision Pro 2 with Neural Display"
    )
  }
#endif
