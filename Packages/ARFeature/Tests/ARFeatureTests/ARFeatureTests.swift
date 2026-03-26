import Testing

@testable import ARFeature

@Suite("ARFeature Module Tests")
struct ARFeatureTests {

  @Test("ARFeature module version is defined")
  func moduleVersion() {
    #expect(!ARFeature.version.isEmpty)
  }
}
