import Core
import Foundation
import Testing

@testable import ARFeature

// MARK: - Module Tests

@Suite("ARFeature Module Tests")
struct ARFeatureModuleTests {

  @Test("ARFeature module version is defined")
  func moduleVersion() {
    #expect(!ARFeature.version.isEmpty)
  }

  @Test("ARFeature can access Core types")
  func coreAccess() {
    // Compile-time check: ARFeature can reference Core domain types
    let coord = GeoCoordinate(latitude: 0, longitude: 0)
    #expect(coord != nil)
  }
}
