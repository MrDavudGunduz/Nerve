// swift-tools-version: 5.9

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
    ),
    .testTarget(
      name: "ARFeatureTests",
      dependencies: ["ARFeature"]
    ),
  ]
)
