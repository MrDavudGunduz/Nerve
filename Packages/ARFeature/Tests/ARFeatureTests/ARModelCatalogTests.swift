//
//  ARModelCatalogTests.swift
//  ARFeatureTests
//
//  Created by Davud Gunduz on 17.05.2026.
//

import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - Expanded AR Model Catalog Tests

@Suite("AR Model Catalog — Expanded Coverage")
struct ARModelCatalogExpandedTests {

  // MARK: - Newly Added Categories

  @Test("Health category is AR capable")
  func healthIsARCapable() {
    let item = makeItem(category: .health)
    #expect(item.isARCapable == true)
    #expect(item.arModelName == "health_dna")
  }

  @Test("Environment category is AR capable")
  func environmentIsARCapable() {
    let item = makeItem(category: .environment)
    #expect(item.isARCapable == true)
    #expect(item.arModelName == "environment_globe")
  }

  // MARK: - ARService Integration with New Categories

  @Test("ARService returns model asset for health news item")
  func modelAssetForHealthItem() async {
    let service = ARService()
    let item = makeItem(category: .health)
    let asset = await service.modelAsset(for: item)
    #expect(asset != nil)
    #expect(asset?.name == "health_dna")
  }

  @Test("ARService returns model asset for environment news item")
  func modelAssetForEnvironmentItem() async {
    let service = ARService()
    let item = makeItem(category: .environment)
    let asset = await service.modelAsset(for: item)
    #expect(asset != nil)
    #expect(asset?.name == "environment_globe")
  }

  // MARK: - Catalog Completeness

  @Test("Exactly 4 categories are AR eligible")
  func exactly4CategoriesAREligible() {
    let eligible = NewsCategory.allCases.filter { category in
      makeItem(category: category).isARCapable
    }
    #expect(eligible.count == 4)
  }

  @Test("AR-eligible categories are technology, science, health, environment")
  func eligibleCategoriesAreCorrect() {
    let expected: Set<NewsCategory> = [.technology, .science, .health, .environment]
    let eligible = Set(NewsCategory.allCases.filter { category in
      makeItem(category: category).isARCapable
    })
    #expect(eligible == expected)
  }

  @Test("Non-AR categories return nil model name")
  func nonARCategoriesReturnNil() {
    let nonAR: [NewsCategory] = [.politics, .sports, .entertainment, .business, .other]
    for category in nonAR {
      let item = makeItem(category: category)
      #expect(item.isARCapable == false, "Expected \(category.rawValue) to NOT be AR capable")
      #expect(item.arModelName == nil, "Expected \(category.rawValue) to have nil model name")
    }
  }

  @Test("Each AR-eligible category has a unique model name")
  func uniqueModelNames() {
    let modelNames = NewsCategory.allCases.compactMap { category in
      makeItem(category: category).arModelName
    }
    let uniqueNames = Set(modelNames)
    #expect(modelNames.count == uniqueNames.count, "Duplicate model names detected")
  }

  // MARK: - ViewModel Integration

  @Test("ViewModel loads model for health category item")
  @MainActor
  func viewModelLoadsHealthModel() async throws {
    let item = makeItem(category: .health)
    let vm = ARNewsViewModel(newsItem: item)
    vm.loadModel()
    try await Task.sleep(for: .milliseconds(200))

    // Model will fail (no actual USDZ in test bundle) but should attempt loading.
    let isLoadingOrResolved = vm.modelState == .loading
      || vm.modelState == .loaded
      || vm.modelState != .idle
    #expect(isLoadingOrResolved)
  }

  @Test("ViewModel loads model for environment category item")
  @MainActor
  func viewModelLoadsEnvironmentModel() async throws {
    let item = makeItem(category: .environment)
    let vm = ARNewsViewModel(newsItem: item)
    vm.loadModel()
    try await Task.sleep(for: .milliseconds(200))

    let isLoadingOrResolved = vm.modelState == .loading
      || vm.modelState == .loaded
      || vm.modelState != .idle
    #expect(isLoadingOrResolved)
  }

  // MARK: - Helpers

  private func makeItem(category: NewsCategory) -> NewsItem {
    NewsItem(
      id: "test-catalog-\(category.rawValue)",
      headline: "Test \(category.rawValue) headline",
      summary: "Test summary for \(category.rawValue).",
      source: "TestSource",
      category: category,
      coordinate: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      publishedAt: Date()
    )
  }
}
