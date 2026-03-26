import Testing

@testable import NetworkLayer

@Suite("NetworkLayer Module Tests")
struct NetworkLayerTests {

  @Test("NetworkLayer module version is defined")
  func moduleVersion() {
    #expect(!NetworkLayer.version.isEmpty)
  }
}
