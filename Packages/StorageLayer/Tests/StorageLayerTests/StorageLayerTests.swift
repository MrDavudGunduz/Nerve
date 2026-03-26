import Testing

@testable import StorageLayer

@Suite("StorageLayer Module Tests")
struct StorageLayerTests {

  @Test("StorageLayer module version is defined")
  func moduleVersion() {
    #expect(!StorageLayer.version.isEmpty)
  }
}
