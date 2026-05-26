//
//  NerveUITestsLaunchTests.swift
//  NerveUITests
//
//  Created by Davud Gunduz on 25.03.2026.
//

import XCTest

// MARK: - Launch Tests

/// Launch configuration tests that capture screenshots across all
/// supported UI configurations (light/dark mode, accessibility sizes).
///
/// `runsForEachTargetApplicationUIConfiguration` ensures this test matrix
/// runs automatically for every Xcode scheme configuration.
final class NerveUITestsLaunchTests: XCTestCase {

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    true
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Captures a launch screenshot for each UI configuration.
  ///
  /// The screenshot is saved as a test attachment for visual regression review.
  @MainActor
  func testLaunch() throws {
    let app = XCUIApplication()
    app.launch()

    // Wait for the map view to settle before capturing.
    // The 2-second timeout allows the DI container to bootstrap and
    // the initial view hierarchy to render.
    let mapTab = app.tabBars.buttons["Map"]
    XCTAssertTrue(
      mapTab.waitForExistence(timeout: 5),
      "Map tab should be visible after launch"
    )

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Launch Screen"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Captures a screenshot of the Settings tab for visual regression.
  @MainActor
  func testSettingsScreenshot() throws {
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["Settings"].tap()

    // Wait for the settings content to load.
    let settingsTitle = app.navigationBars["Settings"]
    XCTAssertTrue(
      settingsTitle.waitForExistence(timeout: 3),
      "Settings navigation bar should appear"
    )

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Settings Screen"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
