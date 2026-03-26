import Testing

@testable import AILayer

@Suite("AILayer Module Tests")
struct AILayerTests {

  @Test("AILayer module version is defined")
  func moduleVersion() {
    #expect(!AILayer.version.isEmpty)
  }
}
