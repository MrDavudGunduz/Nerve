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
/// via ARKit with gesture-based manipulation (drag, scale, rotate)
/// and a floating SwiftUI overlay card.
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
/// - ``ARNewsView`` — The primary entry point; adapts to device capabilities.
/// - ``ModelViewerView`` — SceneKit fallback for macOS / Simulator.
/// - ``VolumetricNewsView`` — visionOS volumetric window content.
/// - ``SpatialMapView`` — visionOS immersive space content.
/// - ``AROverlayCard`` — Floating headline + credibility badge overlay.
///
/// ### Architecture
///
/// - ``ARNewsViewModel`` — Drives model loading state and gesture transforms.
/// - ``ARAssetManager`` — Actor-isolated USDZ caching and resolution.
/// - ``ARCapabilityChecker`` — Device capability detection.
/// - ``ARNewsConfiguration`` — Centralized tuning parameters.
/// - ``EntityGestureHandlers`` — Reusable RealityKit gesture logic.
///
/// ## Integration
///
/// ```swift
/// // In NerveApp.swift:
/// WindowGroup(id: "news-3d-viewer") {
///   VolumetricNewsView()
/// }
/// .windowStyle(.volumetric)
///
/// ImmersiveSpace(id: "spatial-map") {
///   SpatialMapView()
/// }
/// .immersionStyle(selection: .constant(.mixed), in: .mixed)
/// ```
public enum ARFeature {

  /// The current version of the ARFeature module.
  public static let version = "1.0.0"
}
