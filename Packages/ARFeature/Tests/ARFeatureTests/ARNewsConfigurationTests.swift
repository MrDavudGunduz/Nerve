import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - ARNewsConfiguration Tests

@Suite("ARNewsConfiguration Constants Tests")
struct ARNewsConfigurationTests {

  @Test("Model placement defaults are within reasonable ranges")
  func modelPlacementDefaults() {
    #expect(ARNewsConfiguration.defaultModelDistance > 0)
    #expect(ARNewsConfiguration.defaultModelDistance < 5.0)
    #expect(ARNewsConfiguration.surfacePlacementOffset >= 0)
  }

  @Test("Scale bounds are valid")
  func scaleBoundsAreValid() {
    #expect(ARNewsConfiguration.minScale > 0)
    #expect(ARNewsConfiguration.maxScale > ARNewsConfiguration.minScale)
    #expect(ARNewsConfiguration.maxScale <= 10.0)
  }

  @Test("Animation durations are positive")
  func animationDurationsPositive() {
    #expect(ARNewsConfiguration.entranceAnimationDuration > 0)
    #expect(ARNewsConfiguration.exitAnimationDuration > 0)
    #expect(ARNewsConfiguration.springDampingRatio > 0)
    #expect(ARNewsConfiguration.springDampingRatio <= 1.0)
  }

  @Test("Overlay card dimensions are reasonable")
  func overlayCardDimensions() {
    #expect(ARNewsConfiguration.overlayCardYOffset > 0)
    #expect(ARNewsConfiguration.overlayCardMaxWidth > 100)
    #expect(ARNewsConfiguration.overlayCardMaxWidth < 600)
  }

  @Test("Volumetric window size has positive dimensions")
  func volumetricWindowSize() {
    let size = ARNewsConfiguration.volumetricWindowSize
    #expect(size.x > 0)
    #expect(size.y > 0)
    #expect(size.z > 0)
  }

  @Test("Cache configuration has sane defaults")
  func cacheConfiguration() {
    #expect(ARNewsConfiguration.maxCachedModels > 0)
    #expect(ARNewsConfiguration.maxCacheSizeBytes > 0)
    #expect(!ARNewsConfiguration.cacheDirectoryName.isEmpty)
  }

  @Test("Placeholder configuration is reasonable")
  func placeholderConfiguration() {
    #expect(ARNewsConfiguration.placeholderSize > 0)
    #expect(ARNewsConfiguration.placeholderRotationSpeed > 0)
  }
}
