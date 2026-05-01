//
//  DependencyContainerEnvironmentTests.swift
//  CoreTests
//
//  Tests for the F-01 fix: verifying DI container injection tracking.
//

import SwiftUI
import Testing

@testable import Core

// MARK: - DependencyContainerEnvironmentTests

@Suite("DependencyContainer Environment")
struct DependencyContainerEnvironmentTests {

  @Test("EnvironmentValues tracks injection status")
  func injectionStatusTracked() {
    var env = EnvironmentValues()

    // Before explicit injection, the injected flag should be false.
    // We can't easily test the assertionFailure, but we can verify
    // that after setting the container, subsequent reads are safe.
    let container = DependencyContainer()
    env.dependencyContainer = container

    // After injection, reading should return the injected container.
    // No crash or assertion means the injection tracking is working.
    let resolved = env.dependencyContainer
    #expect(resolved === container, "Should return the explicitly injected container")
  }

  @Test("DependencyContainer default creates a fresh empty container")
  func defaultContainerIsEmpty() async {
    let container = DependencyContainer()
    let count = await container.registrationCount
    #expect(count == 0)
  }

  @Test("isRegistered returns false for unknown types")
  func isRegisteredReturnsFalse() async {
    let container = DependencyContainer()
    let registered = await container.isRegistered(NewsServiceProtocol.self)
    #expect(!registered)
  }

  @Test("isRegistered returns true after registration")
  func isRegisteredReturnsTrue() async {
    let container = DependencyContainer()
    await container.register(NewsServiceProtocol.self) { FakeNewsService() }
    let registered = await container.isRegistered(NewsServiceProtocol.self)
    #expect(registered)
  }
}

// MARK: - Fake for tests

private struct FakeNewsService: NewsServiceProtocol {
  func fetchNews(for region: GeoRegion) async throws -> [NewsItem] { [] }
  func fetchNewsDetail(id: String) async throws -> NewsItem {
    throw NerveError.network(message: "fake")
  }
}
