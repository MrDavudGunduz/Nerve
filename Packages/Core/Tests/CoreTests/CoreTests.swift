import Testing

@testable import Core

@Suite("Core Module Tests")
struct CoreTests {

  @Test("Core module version is defined")
  func moduleVersion() {
    #expect(!Core.version.isEmpty)
  }
}
