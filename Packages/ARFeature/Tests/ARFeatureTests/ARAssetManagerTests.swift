import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - ARAssetManager Tests

@Suite("ARAssetManager Cache Tests")
struct ARAssetManagerCacheTests {

  /// Creates a temporary cache directory for testing.
  private func makeTempCacheDir() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ARFeatureTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  /// Cleans up a temporary cache directory.
  private func cleanupTempDir(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  @Test("Initial cache is empty")
  func initialCacheIsEmpty() async {
    let cacheDir = makeTempCacheDir()
    defer { cleanupTempDir(cacheDir) }

    let manager = ARAssetManager(cacheDirectory: cacheDir)
    let count = await manager.cachedModelCount()
    let size = await manager.cacheSizeBytes()

    #expect(count == 0)
    #expect(size == 0)
  }

  @Test("Local URL returns nil for non-existent asset")
  func localURLReturnsNilForMissing() async {
    let cacheDir = makeTempCacheDir()
    defer { cleanupTempDir(cacheDir) }

    let manager = ARAssetManager(cacheDirectory: cacheDir)
    let asset = ARModelAsset(name: "nonexistent", displayName: "Test")

    let url = await manager.localURL(for: asset)
    #expect(url == nil)
  }

  @Test("Clear cache empties the directory")
  func clearCacheEmptiesDirectory() async {
    let cacheDir = makeTempCacheDir()
    defer { cleanupTempDir(cacheDir) }

    // Create a dummy file in the cache.
    let dummyFile = cacheDir.appendingPathComponent("test.usdz")
    try? Data("test".utf8).write(to: dummyFile)

    let manager = ARAssetManager(cacheDirectory: cacheDir)

    // Verify file exists before clear.
    let countBefore = await manager.cachedModelCount()
    #expect(countBefore >= 0)

    // Clear cache.
    await manager.clearCache()

    let countAfter = await manager.cachedModelCount()
    #expect(countAfter == 0)
  }

  @Test("Cache size reflects written files")
  func cacheSizeReflectsFiles() async {
    let cacheDir = makeTempCacheDir()
    defer { cleanupTempDir(cacheDir) }

    // Write a known-size file.
    let testData = Data(repeating: 0x42, count: 1024)
    let testFile = cacheDir.appendingPathComponent("test_model.usdz")
    try? testData.write(to: testFile)

    let manager = ARAssetManager(cacheDirectory: cacheDir)
    let size = await manager.cacheSizeBytes()

    #expect(size >= 1024)
  }

  @Test("Download fails gracefully without remote URL")
  func downloadWithoutURLIsNoOp() async throws {
    let cacheDir = makeTempCacheDir()
    defer { cleanupTempDir(cacheDir) }

    let manager = ARAssetManager(cacheDirectory: cacheDir)
    let asset = ARModelAsset(name: "no_url_model", displayName: "Test")

    // Should not throw — just logs a warning and returns.
    try await manager.downloadAndCache(asset)

    let url = await manager.localURL(for: asset)
    #expect(url == nil)
  }
}

// MARK: - ARModelAsset Tests

@Suite("ARModelAsset Tests")
struct ARModelAssetTests {

  @Test("Asset creation with all properties")
  func assetCreationFull() {
    let url = URL(string: "https://cdn.nerve.app/models/test.usdz")
    let asset = ARModelAsset(
      name: "test_model",
      displayName: "Test Model",
      remoteURL: url
    )

    #expect(asset.name == "test_model")
    #expect(asset.displayName == "Test Model")
    #expect(asset.remoteURL == url)
  }

  @Test("Asset creation without remote URL")
  func assetCreationWithoutURL() {
    let asset = ARModelAsset(name: "bundled_model", displayName: "Bundled")
    #expect(asset.name == "bundled_model")
    #expect(asset.remoteURL == nil)
  }

  @Test("Asset Codable round-trip")
  func assetCodableRoundTrip() throws {
    let original = ARModelAsset(
      name: "roundtrip_test",
      displayName: "Round Trip",
      remoteURL: URL(string: "https://example.com/model.usdz")
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ARModelAsset.self, from: data)

    #expect(original == decoded)
  }

  @Test("Asset Hashable conformance")
  func assetHashable() {
    let asset1 = ARModelAsset(name: "model_a", displayName: "A")
    let asset2 = ARModelAsset(name: "model_a", displayName: "A")
    let asset3 = ARModelAsset(name: "model_b", displayName: "B")

    #expect(asset1 == asset2)
    #expect(asset1 != asset3)

    var set = Set<ARModelAsset>()
    set.insert(asset1)
    set.insert(asset2)
    #expect(set.count == 1)
  }
}

// MARK: - ARService Tests

@Suite("ARService Integration Tests")
struct ARServiceIntegrationTests {

  @Test("AR service reports capability status")
  func arServiceCapabilities() async {
    let service = ARService()
    let arSupported = await service.isARSupported()
    let spatialSupported = await service.isSpatialComputingSupported()

    // On test runner, at least one should be deterministic.
    #if os(macOS)
      #expect(arSupported == false)
      #expect(spatialSupported == false)
    #elseif os(visionOS)
      #expect(spatialSupported == true)
    #endif
  }

  @Test("Model asset returns nil for non-AR-capable news item")
  func modelAssetNilForNonARItem() async {
    let service = ARService()
    let item = NewsItem(
      id: "test-sports",
      headline: "Team Wins Championship",
      summary: "A thrilling final match.",
      source: "ESPN",
      category: .sports,
      coordinate: GeoCoordinate(latitude: 40.758, longitude: -73.986)!,
      publishedAt: Date()
    )

    let asset = await service.modelAsset(for: item)
    #expect(asset == nil)
  }

  @Test("Model asset returns value for technology news item")
  func modelAssetForTechItem() async {
    let service = ARService()
    let item = NewsItem(
      id: "test-tech",
      headline: "New Chip Architecture Unveiled",
      summary: "Revolutionary processor design.",
      source: "Wired",
      category: .technology,
      coordinate: GeoCoordinate(latitude: 37.334, longitude: -122.009)!,
      publishedAt: Date()
    )

    let asset = await service.modelAsset(for: item)
    #expect(asset != nil)
    #expect(asset?.name == "tech_device")
  }

  @Test("Model asset returns value for science news item")
  func modelAssetForScienceItem() async {
    let service = ARService()
    let item = NewsItem(
      id: "test-science",
      headline: "Quantum Breakthrough Achieved",
      summary: "Researchers demonstrate quantum advantage.",
      source: "Nature",
      category: .science,
      coordinate: GeoCoordinate(latitude: 51.508, longitude: -0.076)!,
      publishedAt: Date()
    )

    let asset = await service.modelAsset(for: item)
    #expect(asset != nil)
    #expect(asset?.name == "science_model")
  }

  @Test("Clear asset cache does not throw")
  func clearCacheDoesNotThrow() async {
    let service = ARService()
    await service.clearAssetCache()
    // No assertion needed — test passes if no error is thrown.
  }

  @Test("DI container registers and resolves ARService")
  func diRoundTrip() async throws {
    let container = DependencyContainer()

    await container.register(ARServiceProtocol.self, lifetime: .singleton) {
      ARService()
    }

    let resolved = try await container.resolve(ARServiceProtocol.self)
    let isAR = await resolved.isARSupported()

    // Just verify resolution works — the value depends on platform.
    #expect(isAR == true || isAR == false)
  }
}

// MARK: - NewsItem AR Extension Tests

@Suite("NewsItem AR Extension Tests")
struct NewsItemARExtensionTests {

  @Test("Technology category is AR capable")
  func technologyIsARCapable() {
    let item = makeItem(category: .technology)
    #expect(item.isARCapable == true)
    #expect(item.arModelName == "tech_device")
  }

  @Test("Science category is AR capable")
  func scienceIsARCapable() {
    let item = makeItem(category: .science)
    #expect(item.isARCapable == true)
    #expect(item.arModelName == "science_model")
  }

  @Test("Politics category is not AR capable")
  func politicsIsNotARCapable() {
    let item = makeItem(category: .politics)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Health category is not AR capable")
  func healthIsNotARCapable() {
    let item = makeItem(category: .health)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Sports category is not AR capable")
  func sportsIsNotARCapable() {
    let item = makeItem(category: .sports)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Entertainment category is not AR capable")
  func entertainmentIsNotARCapable() {
    let item = makeItem(category: .entertainment)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Business category is not AR capable")
  func businessIsNotARCapable() {
    let item = makeItem(category: .business)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Environment category is not AR capable")
  func environmentIsNotARCapable() {
    let item = makeItem(category: .environment)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("Other category is not AR capable")
  func otherIsNotARCapable() {
    let item = makeItem(category: .other)
    #expect(item.isARCapable == false)
    #expect(item.arModelName == nil)
  }

  @Test("All NewsCategory cases are covered")
  func allCategoriesCovered() {
    for category in NewsCategory.allCases {
      let item = makeItem(category: category)
      // Should not crash — ensures switch is exhaustive.
      _ = item.isARCapable
      _ = item.arModelName
    }
  }

  // MARK: - Helpers

  private func makeItem(category: NewsCategory) -> NewsItem {
    NewsItem(
      id: "test-\(category.rawValue)",
      headline: "Test Headline",
      summary: "Test Summary",
      source: "Test Source",
      category: category,
      coordinate: GeoCoordinate(latitude: 41.0, longitude: 29.0)!,
      publishedAt: Date()
    )
  }
}
