//
//  ARNewsViewModelTrackingTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 16.05.2026.
//

import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - ARNewsViewModel Tracking & Placement Tests

@Suite("ARNewsViewModel — Tracking & Placement", .tags(.viewModel))
@MainActor
struct ARNewsViewModelTrackingTests {

  // MARK: - Helpers

  private func makeTechItem() -> NewsItem {
    NewsItem(
      id: "test-tracking-1",
      headline: "Test AR Headline",
      summary: "Test summary.",
      source: "TestSource",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date()
    )
  }

  // MARK: - Initial State

  @Test("Non-AR mode skips coaching flow")
  func nonARModeSkipsCoaching() {
    // On macOS/Simulator, viewerMode will be .modelViewer.
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    // If we're running in a non-AR context, placement should be .placed.
    if vm.viewerMode != .augmentedReality {
      #expect(vm.placementState == .placed)
      #expect(vm.trackingQuality == .good)
      #expect(!vm.showCoaching)
    }
  }

  @Test("Initial tracking quality is set based on viewer mode")
  func initialTrackingQuality() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    if vm.viewerMode == .augmentedReality {
      #expect(vm.trackingQuality == .initializing)
    } else {
      #expect(vm.trackingQuality == .good)
    }
  }

  // MARK: - Tracking Updates

  @Test("updateTrackingQuality changes state")
  func updateTrackingQuality() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.updateTrackingQuality(.limited)
    #expect(vm.trackingQuality == .limited)
  }

  @Test("updateTrackingQuality to good")
  func updateToGood() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.updateTrackingQuality(.limited)
    vm.updateTrackingQuality(.good)
    #expect(vm.trackingQuality == .good)
  }

  // MARK: - Surface Detection

  @Test("onSurfaceDetected transitions from coaching to surfaceDetected")
  func surfaceDetectionTransition() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    if vm.viewerMode == .augmentedReality {
      #expect(vm.placementState == .coaching)
      vm.onSurfaceDetected()
      #expect(vm.placementState == .surfaceDetected)
    }
  }

  @Test("onSurfaceDetected is no-op when not in coaching state")
  func surfaceDetectionNoOpWhenPlaced() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    if vm.viewerMode != .augmentedReality {
      let initial = vm.placementState
      vm.onSurfaceDetected()
      #expect(vm.placementState == initial)
    }
  }

  // MARK: - Entity Placement

  @Test("beginEntityPlacement transitions to animatingEntrance")
  func beginPlacement() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.beginEntityPlacement()
    #expect(vm.placementState == .animatingEntrance)
  }

  @Test("completeEntityPlacement transitions to placed")
  func completePlacement() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.beginEntityPlacement()
    vm.completeEntityPlacement()
    #expect(vm.placementState == .placed)
    #expect(vm.placementState.isInteractive)
  }

  // MARK: - Skip Coaching

  @Test("skipCoaching triggers entity placement")
  func skipCoaching() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.skipCoaching()
    #expect(vm.placementState == .animatingEntrance)
  }

  // MARK: - Reset

  @Test("reset restores tracking and placement state")
  func resetState() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    vm.updateTrackingQuality(.good)
    vm.beginEntityPlacement()
    vm.completeEntityPlacement()

    vm.reset()

    if vm.viewerMode == .augmentedReality {
      #expect(vm.placementState == .coaching)
      #expect(vm.trackingQuality == .initializing)
    } else {
      #expect(vm.placementState == .placed)
      #expect(vm.trackingQuality == .good)
    }
    #expect(vm.currentScale == 1.0)
    #expect(vm.currentRotation == 0.0)
    #expect(vm.isOverlayVisible)
  }

  // MARK: - Coaching State Derivation

  @Test("coachingState is scanning during coaching placement")
  func coachingStateDerived() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    if vm.viewerMode == .augmentedReality {
      #expect(vm.coachingState == .scanning)
    }
  }

  @Test("coachingState is detected after surface detection")
  func coachingStateDetected() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())

    if vm.viewerMode == .augmentedReality {
      vm.onSurfaceDetected()
      #expect(vm.coachingState == .detected)
    }
  }

  // MARK: - Scale Clamping

  @Test("Scale clamping within bounds returns same value")
  func scaleClampingWithinBounds() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    let result = vm.clampedScale(1.5)
    #expect(result == 1.5)
  }

  @Test("Scale clamping below minimum returns minimum")
  func scaleClampingBelowMin() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    let result = vm.clampedScale(0.01)
    #expect(result == ARNewsConfiguration.minScale)
  }

  @Test("Scale clamping above maximum returns maximum")
  func scaleClampingAboveMax() {
    let vm = ARNewsViewModel(newsItem: makeTechItem())
    let result = vm.clampedScale(10.0)
    #expect(result == ARNewsConfiguration.maxScale)
  }
}

// MARK: - Tags

extension Tag {
  @Tag static var viewModel: Self
}
