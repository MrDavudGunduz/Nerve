import Testing

@testable import MapFeature

@Suite("MapFeature Module Tests")
struct MapFeatureTests {

  @Test("MapFeature module version is defined")
  func moduleVersion() {
    #expect(!MapFeature.version.isEmpty)
  }
}
