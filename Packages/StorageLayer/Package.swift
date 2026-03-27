// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "StorageLayer",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "StorageLayer", targets: ["StorageLayer"])
  ],
  dependencies: [
    .package(path: "../Core")
  ],
  targets: [
    .target(
      name: "StorageLayer",
      dependencies: ["Core"]
    ),
    .testTarget(
      name: "StorageLayerTests",
      dependencies: ["StorageLayer"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
