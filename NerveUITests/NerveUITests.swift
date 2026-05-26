//
//  NerveUITests.swift
//  NerveUITests
//
//  Created by Davud Gunduz on 25.03.2026.
//

import XCTest

// MARK: - NerveUITests

/// UI automation tests verifying end-to-end app behavior.
///
/// These tests launch the full app and interact with the UI to verify:
/// - Tab navigation works across all tabs.
/// - Settings controls are accessible and functional.
/// - The map view loads without crash.
///
/// ## Running
///
/// ```bash
/// xcodebuild test -scheme Nerve -destination 'platform=iOS Simulator,name=iPhone 16'
/// ```
final class NerveUITests: XCTestCase {

  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Tab Navigation

  /// Verifies that tapping each tab switches the visible content without crashing.
  @MainActor
  func testTabNavigationCycle() throws {
    // Map tab should be selected by default.
    let mapTab = app.tabBars.buttons["Map"]
    XCTAssertTrue(mapTab.exists, "Map tab should exist")

    // Navigate to Headlines.
    let headlinesTab = app.tabBars.buttons["Headlines"]
    XCTAssertTrue(headlinesTab.exists, "Headlines tab should exist")
    headlinesTab.tap()

    // Navigate to Insights.
    let insightsTab = app.tabBars.buttons["Insights"]
    XCTAssertTrue(insightsTab.exists, "Insights tab should exist")
    insightsTab.tap()

    // Navigate to Settings.
    let settingsTab = app.tabBars.buttons["Settings"]
    XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    settingsTab.tap()

    // Return to Map.
    mapTab.tap()
  }

  // MARK: - Settings View

  /// Verifies that the Settings tab displays the expected UI elements.
  @MainActor
  func testSettingsViewElements() throws {
    // Navigate to Settings.
    app.tabBars.buttons["Settings"].tap()

    // Verify key accessibility identifiers are present.
    XCTAssertTrue(
      app.staticTexts["settings-cached-items"].waitForExistence(timeout: 5)
        || app.otherElements["settings-cached-items"].waitForExistence(timeout: 2),
      "Cached items row should exist in Settings"
    )

    let clearCacheButton = app.buttons["settings-clear-cache"]
    XCTAssertTrue(
      clearCacheButton.waitForExistence(timeout: 3),
      "Clear Cache button should exist"
    )

    let versionRow = app.staticTexts["settings-version"]
      .waitForExistence(timeout: 2)
      || app.otherElements["settings-version"].waitForExistence(timeout: 2)
    XCTAssertTrue(versionRow, "Version row should exist in Settings")
  }

  // MARK: - Map View Launch

  /// Verifies the map view loads without crashing on launch.
  ///
  /// This is a smoke test — it confirms that the composition root
  /// (DI container + ModelContainer + service registration) assembles
  /// successfully and the map view renders without a fatal error.
  @MainActor
  func testMapViewLaunchesWithoutCrash() throws {
    // The app should launch to the Map tab by default.
    // Give the map time to render.
    let mapTab = app.tabBars.buttons["Map"]
    XCTAssertTrue(mapTab.exists)
    XCTAssertTrue(mapTab.isSelected, "Map should be the default tab")

    // Simply surviving to this point without a crash is the assertion.
    // Verify the app is still responsive by interacting with a tab.
    app.tabBars.buttons["Settings"].tap()
    app.tabBars.buttons["Map"].tap()
  }

  // MARK: - Launch Performance

  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
