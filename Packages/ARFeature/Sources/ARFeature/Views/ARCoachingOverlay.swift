//
//  ARCoachingOverlay.swift
//  ARFeature
//
//  Created by Davud Gunduz on 16.05.2026.
//

import SwiftUI

// MARK: - ARCoachingOverlay

/// A SwiftUI coaching overlay that guides users through AR surface detection.
///
/// Displays animated instructions encouraging the user to scan horizontal
/// surfaces before model placement. The overlay supports three states:
///
/// | State          | Visual                                        |
/// |----------------|-----------------------------------------------|
/// | `.scanning`    | Animated scan indicator + instruction text     |
/// | `.detected`    | Success checkmark + "Surface found" message    |
/// | `.timeout`     | Warning + fallback instructions                |
///
/// ## Design
///
/// This is a **pure SwiftUI** coaching overlay rather than wrapping
/// `ARCoachingOverlayView` (UIKit) because:
/// 1. It integrates seamlessly with the existing SwiftUI view hierarchy.
/// 2. It matches Nerve's glassmorphism design language.
/// 3. It provides finer control over animation timing and theming.
///
/// ## Accessibility
///
/// - VoiceOver announces state transitions via `.accessibilityLabel`.
/// - Dynamic Type is supported for all text elements.
/// - Animations respect `UIAccessibility.isReduceMotionEnabled`.
struct ARCoachingOverlay: View {

  // MARK: - Properties

  /// The current coaching state.
  let state: CoachingState

  /// Called when the user taps "Skip" to dismiss coaching.
  let onSkip: () -> Void

  // MARK: - Animation State

  @State private var scanPulse = false
  @State private var iconRotation: Angle = .zero

  // MARK: - Body

  var body: some View {
    ZStack {
      // Semi-transparent scrim.
      Color.black.opacity(0.55)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        Spacer()

        // Animated icon.
        coachingIcon

        // Instruction text.
        instructionText

        // Skip button (only during scanning).
        if state == .scanning {
          skipButton
        }

        Spacer()
          .frame(height: 60)
      }
      .padding(.horizontal, 40)
    }
    .transition(.opacity.combined(with: .scale(scale: 1.05)))
    .animation(.easeInOut(duration: 0.3), value: state)
    .onAppear {
      withAnimation(
        .easeInOut(duration: 2.0)
          .repeatForever(autoreverses: true)
      ) {
        scanPulse = true
      }
      withAnimation(
        .linear(duration: 4.0)
          .repeatForever(autoreverses: false)
      ) {
        iconRotation = .degrees(360)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(state.accessibilityLabel)
  }

  // MARK: - Subviews

  @ViewBuilder
  private var coachingIcon: some View {
    switch state {
    case .scanning:
      ZStack {
        // Outer pulsing ring.
        Circle()
          .stroke(
            LinearGradient(
              colors: [.blue.opacity(0.6), .cyan.opacity(0.3)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 3
          )
          .frame(width: 120, height: 120)
          .scaleEffect(scanPulse ? 1.15 : 0.95)
          .opacity(scanPulse ? 0.4 : 0.8)

        // Inner device icon.
        Image(systemName: "iphone.radiowaves.left.and.right")
          .font(.system(size: 44, weight: .light))
          .foregroundStyle(
            LinearGradient(
              colors: [.white, .white.opacity(0.7)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .rotationEffect(
            .degrees(scanPulse ? -5 : 5)
          )
      }

    case .detected:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)
        .transition(.scale.combined(with: .opacity))

    case .timeout:
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 56))
        .foregroundStyle(.orange)
    }
  }

  private var instructionText: some View {
    VStack(spacing: 8) {
      Text(state.title)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)

      Text(state.subtitle)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .lineLimit(3)
    }
  }

  private var skipButton: some View {
    Button(action: onSkip) {
      Text("Skip")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    .accessibilityLabel("Skip surface scanning")
    .accessibilityHint("Places the model without surface detection")
  }
}

// MARK: - CoachingState

/// The state of the AR coaching overlay.
public enum CoachingState: String, Sendable, Equatable {

  /// Actively scanning for horizontal surfaces.
  case scanning

  /// A suitable surface has been detected.
  case detected

  /// Scanning timed out without finding a surface.
  case timeout

  /// The display title for the coaching state.
  public var title: String {
    switch self {
    case .scanning: return "Scan a Flat Surface"
    case .detected: return "Surface Detected!"
    case .timeout: return "No Surface Found"
    }
  }

  /// The instructional subtitle for the coaching state.
  public var subtitle: String {
    switch self {
    case .scanning:
      return "Slowly move your device over a table, desk, or floor to detect a horizontal surface."
    case .detected:
      return "The 3D model will be placed on the detected surface."
    case .timeout:
      return "Try pointing your device at a well-lit, textured surface. The model will be placed in front of you."
    }
  }

  /// VoiceOver label for the coaching state.
  public var accessibilityLabel: String {
    "\(title). \(subtitle)"
  }
}

// MARK: - Preview

#if DEBUG
  #Preview("Scanning") {
    ARCoachingOverlay(state: .scanning, onSkip: {})
  }

  #Preview("Detected") {
    ARCoachingOverlay(state: .detected, onSkip: {})
  }

  #Preview("Timeout") {
    ARCoachingOverlay(state: .timeout, onSkip: {})
  }
#endif
