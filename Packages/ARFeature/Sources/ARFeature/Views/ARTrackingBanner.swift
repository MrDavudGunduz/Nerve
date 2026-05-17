//
//  ARTrackingBanner.swift
//  ARFeature
//
//  Created by Davud Gunduz on 16.05.2026.
//

import SwiftUI

// MARK: - ARTrackingBanner

/// A compact tracking quality indicator displayed at the top of the AR viewer.
///
/// Shows the current ``ARTrackingQuality`` with a color-coded icon
/// and descriptive text. Automatically fades out when tracking is `.good`
/// to minimize visual clutter during active AR use.
///
/// ## Layout
///
/// ```
/// ┌──────────────────────────────────────┐
/// │  ◉  Move your device to improve...  │
/// └──────────────────────────────────────┘
/// ```
///
/// ## Animation
///
/// - Slides in from the top with a spring animation.
/// - Fades out after 3 seconds when tracking quality is `.good`.
/// - Persists while tracking is `.limited` or `.initializing`.
struct ARTrackingBanner: View {

  // MARK: - Properties

  /// The current tracking quality.
  let quality: ARTrackingQuality

  /// Whether the banner should auto-hide when quality is good.
  @State private var isVisible = true

  // MARK: - Body

  var body: some View {
    if shouldShow {
      HStack(spacing: 8) {
        Image(systemName: quality.iconName)
          .font(.caption)
          .foregroundStyle(iconColor)
          .symbolEffect(.pulse, options: .repeating, isActive: isPulsing)

        Text(quality.userMessage)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.9))
          .lineLimit(1)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(.ultraThinMaterial)
      .clipShape(Capsule())
      .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
      .transition(.move(edge: .top).combined(with: .opacity))
      .animation(.spring(dampingFraction: 0.8), value: quality)
      .onChange(of: quality) { _, newQuality in
        handleQualityChange(newQuality)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Tracking quality: \(quality.rawValue). \(quality.userMessage)")
    }
  }

  // MARK: - Computed Properties

  private var shouldShow: Bool {
    isVisible && quality != .good
  }

  private var isPulsing: Bool {
    quality == .initializing || quality == .limited
  }

  private var iconColor: Color {
    switch quality {
    case .good: return .green
    case .limited: return .orange
    case .initializing: return .blue
    case .unavailable: return .red
    }
  }

  // MARK: - Helpers

  private func handleQualityChange(_ newQuality: ARTrackingQuality) {
    if newQuality == .good {
      // Auto-hide after a brief celebration period.
      withAnimation(.easeOut(duration: 0.3).delay(2.0)) {
        isVisible = false
      }
    } else {
      withAnimation(.spring(dampingFraction: 0.8)) {
        isVisible = true
      }
    }
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Initializing") {
    ZStack {
      Color.black
      VStack {
        ARTrackingBanner(quality: .initializing)
        Spacer()
      }
      .padding(.top, 60)
    }
    .ignoresSafeArea()
  }

  #Preview("Limited") {
    ZStack {
      Color.black
      VStack {
        ARTrackingBanner(quality: .limited)
        Spacer()
      }
      .padding(.top, 60)
    }
    .ignoresSafeArea()
  }
#endif
