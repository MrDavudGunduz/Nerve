//
//  ARNewsConfigurationExtendedTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 16.05.2026.
//

import Testing

@testable import ARFeature

// MARK: - ARNewsConfiguration Extended Tests

@Suite("ARNewsConfiguration — Extended Constants")
struct ARNewsConfigurationExtendedTests {

  // MARK: - Coaching Overlay

  @Test("Coaching overlay is enabled by default")
  func coachingEnabled() {
    #expect(ARNewsConfiguration.showCoachingOverlay)
  }

  @Test("Coaching timeout is positive and reasonable")
  func coachingTimeout() {
    let timeout = ARNewsConfiguration.coachingTimeoutDuration
    #expect(timeout > 0)
    #expect(timeout <= 60, "Timeout should not exceed 60 seconds")
  }

  @Test("Coaching appearance delay is non-negative")
  func coachingDelay() {
    #expect(ARNewsConfiguration.coachingAppearanceDelay >= 0)
  }

  // MARK: - Haptic Feedback

  @Test("Haptic intensities are within valid range [0, 1]")
  func hapticIntensityBounds() {
    let intensities = [
      ARNewsConfiguration.placementHapticIntensity,
      ARNewsConfiguration.gestureStartHapticIntensity,
      ARNewsConfiguration.limitReachedHapticIntensity,
    ]

    for intensity in intensities {
      #expect(intensity >= 0.0 && intensity <= 1.0)
    }
  }

  @Test("Placement haptic is stronger than gesture start")
  func hapticHierarchy() {
    #expect(
      ARNewsConfiguration.placementHapticIntensity
        > ARNewsConfiguration.gestureStartHapticIntensity
    )
  }

  // MARK: - Entrance Animation

  @Test("Entrance start scale is near zero but positive")
  func entranceStartScale() {
    let scale = ARNewsConfiguration.entranceStartScale
    #expect(scale > 0)
    #expect(scale < 0.1, "Start scale should be small for visible animation")
  }

  @Test("Entrance drop offset is positive")
  func entranceDropOffset() {
    #expect(ARNewsConfiguration.entranceDropOffset > 0)
  }

  @Test("Entrance spring response is positive")
  func entranceSpringResponse() {
    #expect(ARNewsConfiguration.entranceSpringResponse > 0)
  }

  @Test("Entrance spring damping is in underdamped range (0, 1)")
  func entranceSpringDamping() {
    let damping = ARNewsConfiguration.entranceSpringDamping
    #expect(damping > 0 && damping < 1)
  }

  // MARK: - Tracking Quality

  @Test("Good tracking threshold is positive")
  func trackingThreshold() {
    #expect(ARNewsConfiguration.goodTrackingFeaturePointThreshold > 0)
  }

  @Test("Tracking warning delay is positive")
  func trackingWarningDelay() {
    #expect(ARNewsConfiguration.trackingWarningDelay > 0)
  }

  // MARK: - Consistency

  @Test("Entrance animation duration matches existing constant")
  func entranceDurationConsistency() {
    #expect(ARNewsConfiguration.entranceAnimationDuration > 0)
    #expect(ARNewsConfiguration.exitAnimationDuration > 0)
    #expect(
      ARNewsConfiguration.entranceAnimationDuration
        >= ARNewsConfiguration.exitAnimationDuration,
      "Entrance should be >= exit for visual weight"
    )
  }
}
