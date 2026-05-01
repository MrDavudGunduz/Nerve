//
//  ARErrorOverlay.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import SwiftUI

// MARK: - ARErrorOverlay

/// A full-screen error state overlay for the AR viewer.
///
/// Displays an icon, a title, the error description, and a retry button.
/// Uses a semi-transparent black scrim consistent with ``ARLoadingOverlay``.
///
/// ## Usage
///
/// ```swift
/// ARErrorOverlay(
///   message: "Network connection lost.",
///   onRetry: { viewModel.reset(); viewModel.loadModel() }
/// )
/// ```
struct ARErrorOverlay: View {

  // MARK: - Properties

  /// The human-readable error description.
  let message: String

  /// Called when the user taps the retry button.
  let onRetry: () -> Void

  // MARK: - Body

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)
        .ignoresSafeArea()

      VStack(spacing: 20) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 48))
          .foregroundStyle(.orange)

        Text("Unable to Load Model")
          .font(.title3)
          .fontWeight(.bold)
          .foregroundStyle(.white)

        Text(message)
          .font(.body)
          .foregroundStyle(.white.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)

        Button("Try Again", action: onRetry)
          .buttonStyle(.borderedProminent)
          .tint(.blue)
          .accessibilityLabel("Retry loading 3D model")
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Error Overlay") {
    ARErrorOverlay(
      message: "No 3D model available for this story.",
      onRetry: {}
    )
  }
#endif
