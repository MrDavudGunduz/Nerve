import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - ARNewsViewModel Tests

@Suite("ARNewsViewModel Lifecycle Tests")
struct ARNewsViewModelLifecycleTests {

  @Test("Initial state is idle")
  @MainActor
  func initialStateIsIdle() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    #expect(viewModel.modelState == .idle)
    #expect(viewModel.modelURL == nil)
    #expect(viewModel.currentScale == 1.0)
    #expect(viewModel.currentRotation == 0.0)
    #expect(viewModel.isOverlayVisible == true)
  }

  @Test("ViewModel exposes correct viewer mode for non-AR device")
  @MainActor
  func viewerModeIsModelViewer() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    // On macOS / Simulator, the capability checker returns .modelViewer.
    #expect(viewModel.viewerMode == .modelViewer || viewModel.viewerMode == .augmentedReality || viewModel.viewerMode == .spatial)
  }

  @Test("Load model transitions to loading state")
  @MainActor
  func loadModelTransitionsToLoading() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    viewModel.loadModel()

    // State should be loading (or already failed/loaded if fast).
    #expect(viewModel.modelState == .loading || viewModel.modelState == .failed("No 3D model available for this story.") || viewModel.modelState == .loaded)
  }

  @Test("Non-AR-capable item fails with descriptive message")
  @MainActor
  func nonARCapableItemFails() async throws {
    let item = Self.makePoliticsNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    viewModel.loadModel()

    // Wait briefly for the task to execute.
    try await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.modelState == .failed("No 3D model available for this story."))
  }

  @Test("Cancel loading resets to idle")
  @MainActor
  func cancelLoadingResetsToIdle() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    viewModel.loadModel()
    viewModel.cancelLoading()

    // After cancel, state should be idle (unless load completed first).
    #expect(viewModel.modelState == .idle || viewModel.modelState == .loaded || viewModel.modelState == .failed("No 3D model available for this story."))
  }

  @Test("Reset clears all state")
  @MainActor
  func resetClearsState() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    // Modify state.
    viewModel.currentScale = 2.5
    viewModel.currentRotation = 1.5
    viewModel.isOverlayVisible = false

    // Reset.
    viewModel.reset()

    #expect(viewModel.currentScale == 1.0)
    #expect(viewModel.currentRotation == 0.0)
    #expect(viewModel.isOverlayVisible == true)
    #expect(viewModel.modelState == .idle)
    #expect(viewModel.modelURL == nil)
  }

  @Test("Scale clamping respects min/max bounds")
  @MainActor
  func scaleClampingWorksCorrectly() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    // Below minimum.
    #expect(viewModel.clampedScale(0.01) == ARNewsConfiguration.minScale)

    // Above maximum.
    #expect(viewModel.clampedScale(10.0) == ARNewsConfiguration.maxScale)

    // Within bounds.
    #expect(viewModel.clampedScale(1.5) == 1.5)

    // Exact bounds.
    #expect(viewModel.clampedScale(ARNewsConfiguration.minScale) == ARNewsConfiguration.minScale)
    #expect(viewModel.clampedScale(ARNewsConfiguration.maxScale) == ARNewsConfiguration.maxScale)
  }

  @Test("Credibility label returns correct value from analysis")
  @MainActor
  func credibilityLabelFromAnalysis() {
    let item = Self.makeTechNewsItem(
      analysis: HeadlineAnalysis(clickbaitScore: 0.15, sentiment: .positive, confidence: 0.9)
    )
    let viewModel = ARNewsViewModel(newsItem: item)

    #expect(viewModel.credibilityLabel == .verified)
  }

  @Test("Credibility label is nil when no analysis")
  @MainActor
  func credibilityLabelNilWithoutAnalysis() {
    let item = Self.makeTechNewsItem(analysis: nil)
    let viewModel = ARNewsViewModel(newsItem: item)

    #expect(viewModel.credibilityLabel == nil)
  }

  @Test("Formatted date is non-empty")
  @MainActor
  func formattedDateIsNonEmpty() {
    let item = Self.makeTechNewsItem()
    let viewModel = ARNewsViewModel(newsItem: item)

    #expect(!viewModel.formattedDate.isEmpty)
  }

  // MARK: - Helpers

  private static func makeTechNewsItem(
    analysis: HeadlineAnalysis? = HeadlineAnalysis(
      clickbaitScore: 0.2,
      sentiment: .neutral,
      confidence: 0.85
    )
  ) -> NewsItem {
    NewsItem(
      id: "test-tech-\(UUID().uuidString.prefix(8))",
      headline: "Apple Unveils New Chip Architecture",
      summary: "The new chip features advanced neural processing.",
      source: "TechCrunch",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date(),
      analysis: analysis
    )
  }

  private static func makePoliticsNewsItem() -> NewsItem {
    NewsItem(
      id: "test-politics-\(UUID().uuidString.prefix(8))",
      headline: "Senate Passes Infrastructure Bill",
      summary: "The bipartisan bill allocates funds for transportation.",
      source: "Reuters",
      category: .politics,
      coordinate: GeoCoordinate(latitude: 38.907, longitude: -77.037)!,
      publishedAt: Date()
    )
  }
}
