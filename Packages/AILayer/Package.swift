// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AILayer",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .visionOS(.v1),
  ],
  products: [
    .library(name: "AILayer", targets: ["AILayer"])
  ],
  dependencies: [
    .package(path: "../Core")
  ],
  targets: [
    .target(
      name: "AILayer",
      dependencies: ["Core"]
    ),
    .testTarget(
      name: "AILayerTests",
      dependencies: ["AILayer"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
