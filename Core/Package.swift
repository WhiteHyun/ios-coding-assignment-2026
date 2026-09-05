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
    ),
    .library(name: "Storage", targets: ["Storage"]),
  ],
  targets: [
    .target(name: "Networker"),
    .target(name: "Storage"),
    .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    .testTarget(
      name: "NetworkerTests",
      dependencies: ["Networker"],
    ),
  ],
  swiftLanguageModes: [.v6],
)
