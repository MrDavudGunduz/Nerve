import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - ARCapabilityChecker Tests

@Suite("ARCapabilityChecker Tests")
struct ARCapabilityCheckerTests {

  let checker = ARCapabilityChecker()

  @Test("3D model viewing is always supported")
  func modelViewingAlwaysSupported() {
    #expect(checker.supports3DModelViewing == true)
  }

  @Test("Recommended viewer mode is valid enum value")
  func recommendedModeIsValid() {
    let mode = checker.recommendedViewerMode
    // Should be one of the three valid modes.
    #expect(
      mode == .augmentedReality || mode == .spatial || mode == .modelViewer
    )
  }

  @Test("RealityKit support matches platform")
  func realityKitSupportMatchesPlatform() {
    let supports = checker.supportsRealityKit
    // On macOS this should be false, on iOS/visionOS true.
    #if os(macOS)
      #expect(supports == false)
    #elseif os(iOS)
      // May be true or false depending on device/simulator.
      #expect(supports == true || supports == false)
    #elseif os(visionOS)
      #expect(supports == true)
    #endif
  }

  @Test("Spatial computing support matches platform")
  func spatialComputingSupportMatchesPlatform() {
    let supports = checker.supportsSpatialComputing
    #if os(visionOS)
      #expect(supports == true)
    #else
      #expect(supports == false)
    #endif
  }

  @Test("World tracking support matches platform")
  func worldTrackingSupportMatchesPlatform() {
    let supports = checker.supportsWorldTracking
    #if os(macOS) || os(visionOS)
      #expect(supports == false)
    #elseif os(iOS)
      // Simulator: false, real device: depends on hardware.
      #expect(supports == true || supports == false)
    #endif
  }
}

// MARK: - ARViewerMode Tests

@Suite("ARViewerMode Tests")
struct ARViewerModeTests {

  @Test("All viewer modes have non-empty raw values")
  func viewerModeRawValues() {
    #expect(!ARViewerMode.augmentedReality.rawValue.isEmpty)
    #expect(!ARViewerMode.spatial.rawValue.isEmpty)
    #expect(!ARViewerMode.modelViewer.rawValue.isEmpty)
  }

  @Test("Viewer modes are distinct")
  func viewerModesAreDistinct() {
    #expect(ARViewerMode.augmentedReality != .spatial)
    #expect(ARViewerMode.augmentedReality != .modelViewer)
    #expect(ARViewerMode.spatial != .modelViewer)
  }

  @Test("Viewer mode round-trips through Codable")
  func viewerModeCodableRoundTrip() throws {
    let original = ARViewerMode.augmentedReality
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ARViewerMode.self, from: data)
    #expect(original == decoded)
  }
}
