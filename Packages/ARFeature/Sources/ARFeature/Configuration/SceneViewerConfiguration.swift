//
//  SceneViewerConfiguration.swift
//  ARFeature
//
//  Created by Davud Gunduz on 01.05.2026.
//

import Foundation

#if canImport(SceneKit)
  import SceneKit
#endif

// MARK: - SceneViewerConfiguration

/// Centralized tuning parameters for the SceneKit model viewer.
///
/// All magic numbers live here so that adjusting the 3D viewer
/// experience requires zero changes to view or scene-building code.
/// Complements ``ARNewsConfiguration`` (which covers RealityKit).
#if canImport(SceneKit)
  enum SceneViewerConfiguration {

    // MARK: Camera

    /// Vertical field of view in degrees.
    static let cameraFieldOfView: CGFloat = 60

    /// Initial camera position relative to the scene origin.
    static let cameraPosition = SCNVector3(0, 0.15, 0.5)

    // MARK: Key Light

    /// Intensity (lumens) of the primary directional light.
    static let keyLightIntensity: CGFloat = 800

    /// Euler angles for the key light direction.
    static let keyLightAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)

    // MARK: Fill Light

    /// Intensity (lumens) of the secondary fill light.
    static let fillLightIntensity: CGFloat = 400

    /// Brightness of the fill light color (0–1).
    static let fillLightWhiteness: CGFloat = 0.9

    /// Euler angles for the fill light direction.
    static let fillLightAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)

    // MARK: Ambient Light

    /// Intensity of the ambient fill.
    static let ambientLightIntensity: CGFloat = 200

    /// Brightness of the ambient light color (0–1).
    static let ambientLightWhiteness: CGFloat = 0.8

    // MARK: Auto-Rotation

    /// Duration (seconds) for one full 360° rotation.
    static let autoRotationDuration: TimeInterval = 30

    // MARK: Placeholder Geometry

    /// Edge length (meters) of the placeholder cube.
    static let placeholderEdge: CGFloat = 0.1

    /// Corner radius (meters) of the placeholder cube.
    static let placeholderChamfer: CGFloat = 0.01

    /// Diffuse opacity of the placeholder material.
    static let placeholderOpacity: CGFloat = 0.6

    /// Metalness of the placeholder surface (0–1).
    static let placeholderMetalness: Double = 0.3

    /// Roughness of the placeholder surface (0–1).
    static let placeholderRoughness: Double = 0.7
  }
#endif
