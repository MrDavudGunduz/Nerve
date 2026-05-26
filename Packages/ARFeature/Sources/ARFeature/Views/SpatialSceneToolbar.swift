//
//  SpatialSceneToolbar.swift
//  ARFeature
//
//  Created by Davud Gunduz on 18.05.2026.
//

import Core
import OSLog
import SwiftUI

// MARK: - SpatialSceneToolbar

/// A floating toolbar for transitioning between spatial scene modes.
///
/// Provides three buttons for switching between Standard 2D, Volumetric 3D,
/// and Immersive Space modes. Each button shows the active state and disables
/// during transitions to prevent race conditions.
///
/// ## Layout
///
/// ```
/// ┌───────────────────────────────────────────┐
/// │  [📱 2D]  [🧊 Volumetric]  [🌐 Immersive] │
/// └───────────────────────────────────────────┘
/// ```
///
/// ## Usage
///
/// Place inside a 2D window. The toolbar uses SwiftUI environment actions
/// internally — no manual wiring required.
///
/// ```swift
/// ContentView()
///   .overlay(alignment: .bottom) {
///     SpatialSceneToolbar(transitionManager: transitionManager)
///   }
/// ```
#if os(visionOS)
  public struct SpatialSceneToolbar: View {

    // MARK: - Properties

    @Bindable private var transitionManager: SpatialTransitionManager

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    private static let logger = Logger(
      subsystem: LogSubsystem.arFeature,
      category: "SpatialSceneToolbar"
    )

    // MARK: - Init

    /// Creates a spatial scene toolbar.
    ///
    /// - Parameter transitionManager: The shared transition manager.
    public init(transitionManager: SpatialTransitionManager) {
      self.transitionManager = transitionManager
    }

    // MARK: - Body

    public var body: some View {
      HStack(spacing: 12) {
        sceneButton(
          mode: .standard,
          icon: "rectangle.portrait",
          label: "2D"
        )

        sceneButton(
          mode: .volumetric,
          icon: "cube",
          label: "3D Model"
        )

        sceneButton(
          mode: .immersive,
          icon: "globe",
          label: "Immersive"
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(.ultraThinMaterial)
      .clipShape(Capsule())
      .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
      .padding(.bottom, 20)
      .overlay {
        if transitionManager.isTransitioning {
          transitionOverlay
        }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: transitionManager.currentMode)
      .animation(.easeInOut(duration: 0.2), value: transitionManager.isTransitioning)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Scene mode selector")
    }

    // MARK: - Scene Button

    private func sceneButton(
      mode: SpatialSceneMode,
      icon: String,
      label: String
    ) -> some View {
      Button {
        Task {
          await transitionManager.transitionTo(
            mode,
            openWindow: openWindow,
            dismissWindow: dismissWindow,
            openImmersiveSpace: openImmersiveSpace,
            dismissImmersiveSpace: dismissImmersiveSpace
          )
        }
      } label: {
        VStack(spacing: 4) {
          Image(systemName: isActive(mode) ? "\(icon).fill" : icon)
            .font(.title3)
            .symbolEffect(.bounce, value: isActive(mode))

          Text(label)
            .font(.caption2)
            .fontWeight(isActive(mode) ? .bold : .regular)
        }
        .foregroundStyle(isActive(mode) ? .primary : .secondary)
        .frame(minWidth: 64)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
          isActive(mode)
            ? AnyShapeStyle(.tint.opacity(0.15))
            : AnyShapeStyle(.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(transitionManager.isTransitioning)
      .accessibilityLabel("\(label) mode")
      .accessibilityHint(
        isActive(mode)
          ? "Currently active"
          : "Double-tap to switch to \(label) mode"
      )
      .accessibilityAddTraits(isActive(mode) ? .isSelected : [])
    }

    // MARK: - Transition Overlay

    private var transitionOverlay: some View {
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.8)
          .tint(.white)

        Text("Transitioning…")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(.ultraThinMaterial)
      .clipShape(Capsule())
      .offset(y: -50)
      .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Helpers

    private func isActive(_ mode: SpatialSceneMode) -> Bool {
      transitionManager.currentMode == mode
    }
  }

  // MARK: - Preview

  #if DEBUG
    #Preview("Spatial Scene Toolbar") {
      VStack {
        Spacer()
        SpatialSceneToolbar(
          transitionManager: SpatialTransitionManager()
        )
      }
    }
  #endif
#endif
