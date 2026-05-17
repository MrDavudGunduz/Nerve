//
//  ARTrackingStateTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 16.05.2026.
//

import Testing

@testable import ARFeature

// MARK: - ARTrackingQuality Tests

@Suite("ARTrackingQuality")
struct ARTrackingQualityTests {

  @Test("Good quality has correct user message")
  func goodMessage() {
    let quality = ARTrackingQuality.good
    #expect(quality.userMessage.contains("ready"))
  }

  @Test("Limited quality suggests movement")
  func limitedMessage() {
    let quality = ARTrackingQuality.limited
    #expect(quality.userMessage.contains("Move"))
  }

  @Test("Initializing quality shows scanning")
  func initializingMessage() {
    let quality = ARTrackingQuality.initializing
    #expect(quality.userMessage.contains("Scanning"))
  }

  @Test("Unavailable quality indicates no AR")
  func unavailableMessage() {
    let quality = ARTrackingQuality.unavailable
    #expect(quality.userMessage.contains("not available"))
  }

  @Test("Each quality has a unique SF Symbol icon")
  func uniqueIcons() {
    let icons = ARTrackingQuality.allQualities.map(\.iconName)
    #expect(Set(icons).count == icons.count, "Icon names should be unique")
  }

  @Test("Raw values are unique")
  func uniqueRawValues() {
    let values = ARTrackingQuality.allQualities.map(\.rawValue)
    #expect(Set(values).count == values.count, "Raw values should be unique")
  }
}

// MARK: - ARPlacementState Tests

@Suite("ARPlacementState")
struct ARPlacementStateTests {

  @Test("Coaching is not interactive")
  func coachingNotInteractive() {
    #expect(!ARPlacementState.coaching.isInteractive)
  }

  @Test("SurfaceDetected is not interactive")
  func surfaceDetectedNotInteractive() {
    #expect(!ARPlacementState.surfaceDetected.isInteractive)
  }

  @Test("AnimatingEntrance is not interactive")
  func animatingEntranceNotInteractive() {
    #expect(!ARPlacementState.animatingEntrance.isInteractive)
  }

  @Test("Placed is interactive")
  func placedIsInteractive() {
    #expect(ARPlacementState.placed.isInteractive)
  }

  @Test("Equatable conformance")
  func equatable() {
    #expect(ARPlacementState.coaching == ARPlacementState.coaching)
    #expect(ARPlacementState.placed != ARPlacementState.coaching)
  }
}

// MARK: - Helpers

extension ARTrackingQuality {
  /// All tracking quality cases for testing.
  static var allQualities: [ARTrackingQuality] {
    [.good, .limited, .initializing, .unavailable]
  }
}
