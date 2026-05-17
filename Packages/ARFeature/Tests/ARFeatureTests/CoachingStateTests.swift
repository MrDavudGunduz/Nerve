//
//  CoachingStateTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 16.05.2026.
//

import Testing

@testable import ARFeature

// MARK: - CoachingState Tests

@Suite("CoachingState")
struct CoachingStateTests {

  @Test("Scanning state has correct title")
  func scanningTitle() {
    #expect(CoachingState.scanning.title == "Scan a Flat Surface")
  }

  @Test("Detected state has correct title")
  func detectedTitle() {
    #expect(CoachingState.detected.title == "Surface Detected!")
  }

  @Test("Timeout state has correct title")
  func timeoutTitle() {
    #expect(CoachingState.timeout.title == "No Surface Found")
  }

  @Test("Scanning subtitle instructs surface scanning")
  func scanningSubtitle() {
    #expect(CoachingState.scanning.subtitle.contains("Slowly move"))
  }

  @Test("Detected subtitle confirms placement")
  func detectedSubtitle() {
    #expect(CoachingState.detected.subtitle.contains("placed"))
  }

  @Test("Timeout subtitle suggests well-lit surface")
  func timeoutSubtitle() {
    #expect(CoachingState.timeout.subtitle.contains("well-lit"))
  }

  @Test("Accessibility label combines title and subtitle")
  func accessibilityLabel() {
    let state = CoachingState.scanning
    #expect(state.accessibilityLabel == "\(state.title). \(state.subtitle)")
  }

  @Test("All states have non-empty titles")
  func nonEmptyTitles() {
    for state in [CoachingState.scanning, .detected, .timeout] {
      #expect(!state.title.isEmpty)
    }
  }

  @Test("All states have non-empty subtitles")
  func nonEmptySubtitles() {
    for state in [CoachingState.scanning, .detected, .timeout] {
      #expect(!state.subtitle.isEmpty)
    }
  }

  @Test("Equatable conformance works correctly")
  func equatable() {
    #expect(CoachingState.scanning == CoachingState.scanning)
    #expect(CoachingState.scanning != CoachingState.detected)
    #expect(CoachingState.detected != CoachingState.timeout)
  }
}
