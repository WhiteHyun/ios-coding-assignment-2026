// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Core",
  platforms: [
    .iOS(.v17)
  ],
  products: [
    .library(
      name: "Networker",
      targets: ["Networker"],
    )
  ],
  targets: [
    .target(name: "Networker"),
    .testTarget(
      name: "NetworkerTests",
      dependencies: ["Networker"],
    ),
  ],
  swiftLanguageModes: [.v6],
)
