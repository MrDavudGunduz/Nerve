//
//  ARFeature.swift
//  ARFeature
//
//  Created by Davud Gunduz on 25.03.2026.
//

import Core

/// Augmented reality and spatial computing experiences for
/// news exploration.
///
/// On **iOS**, renders USDZ models anchored to real-world surfaces
/// via ARKit with gesture-based manipulation (drag, scale, rotate),
/// a coaching overlay for surface detection guidance, haptic feedback,
/// spring-based entrance animations, and a floating SwiftUI overlay card.
///
/// On **visionOS**, provides:
/// - **Volumetric windows** — detach 3D news models into the user's space.
/// - **Immersive spaces** — navigate a spatial 3D news map.
///
/// On **macOS** and non-AR devices, gracefully degrades to a
/// SceneKit-based 3D model viewer with orbit camera controls.
///
/// ## Key Components
///
/// ### Views
///
/// - ``ARNewsView`` — The primary SwiftUI entry point; adapts to device capabilities.
/// - ``ARNewsViewController`` — UIKit-hosted wrapper for UINavigationController integration.
/// - ``ModelViewerView`` — SceneKit fallback for macOS / Simulator.
/// - ``VolumetricNewsView`` — visionOS volumetric window content.
/// - ``SpatialMapView`` — visionOS immersive space content.
/// - ``AROverlayCard`` — Floating headline + credibility badge overlay.
/// - ``ARCoachingOverlay`` — Guided surface detection overlay.
/// - ``ARTrackingBanner`` — Compact tracking quality indicator.
///
/// ### Architecture
///
/// - ``ARNewsViewModel`` — Drives model loading state, placement lifecycle,
///   tracking quality, and gesture transforms.
/// - ``ARAssetManager`` — Actor-isolated USDZ caching and resolution.
/// - ``ARCapabilityChecker`` — Device capability detection.
/// - ``ARNewsConfiguration`` — Centralized tuning parameters.
/// - ``EntityGestureHandlers`` — Reusable RealityKit gesture logic with haptics.
/// - ``EntityAnimations`` — Spring-based entrance, exit, and pulse animations.
/// - ``ARHapticEngine`` — Core Haptics feedback for AR interactions (iOS).
/// - ``ARSessionCoordinator`` — ARKit session delegate bridge (iOS).
/// - ``EntityLifecycleManager`` — VRAM-safe entity tracking and teardown.
/// - ``ARTrackingQuality`` — Tracking state value types.
/// - ``ARPlacementState`` — Entity placement lifecycle state machine.
///
/// ## AR-Eligible Categories
///
/// | Category       | USDZ Model         |
/// |----------------|--------------------|
/// | `.technology`  | `tech_device`      |
/// | `.science`     | `science_model`    |
/// | `.health`      | `health_dna`       |
/// | `.environment` | `environment_globe`|
///
/// ## Integration
///
/// ```swift
/// // SwiftUI entry point:
/// ARNewsView(newsItem: item)
///   .navigationTitle("AR Preview")
///
/// // UIKit entry point:
/// let arVC = ARNewsViewController(newsItem: item)
/// navigationController?.pushViewController(arVC, animated: true)
///
/// // visionOS volumetric window:
/// WindowGroup(id: "news-3d-viewer") {
///   VolumetricNewsView()
/// }
/// .windowStyle(.volumetric)
///
/// // visionOS immersive space:
/// ImmersiveSpace(id: "spatial-map") {
///   SpatialMapView()
/// }
/// .immersionStyle(selection: .constant(.mixed), in: .mixed)
/// ```
public enum ARFeature {

  /// The current version of the ARFeature module.
  public static let version = "1.0.0"
}
