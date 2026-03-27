// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MapFeature",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "MapFeature", targets: ["MapFeature"])
  ],
  dependencies: [
    .package(path: "../Core")
  ],
  targets: [
    .target(
      name: "MapFeature",
      dependencies: ["Core"]
    ),
    .testTarget(
      name: "MapFeatureTests",
      dependencies: ["MapFeature"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
