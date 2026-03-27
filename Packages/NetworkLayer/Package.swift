// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "NetworkLayer",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "NetworkLayer", targets: ["NetworkLayer"])
  ],
  dependencies: [
    .package(path: "../Core")
  ],
  targets: [
    .target(
      name: "NetworkLayer",
      dependencies: ["Core"]
    ),
    .testTarget(
      name: "NetworkLayerTests",
      dependencies: ["NetworkLayer"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
