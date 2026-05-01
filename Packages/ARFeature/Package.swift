// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ARFeature",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "ARFeature", targets: ["ARFeature"])
  ],
  dependencies: [
    .package(path: "../Core")
  ],
  targets: [
    .target(
      name: "ARFeature",
      dependencies: ["Core"]
      // When USDZ model files are added, uncomment the resources block:
      // resources: [.process("Resources")]
    ),
    .testTarget(
      name: "ARFeatureTests",
      dependencies: ["ARFeature"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
