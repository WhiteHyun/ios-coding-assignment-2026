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
    .library(name: "Architecture", targets: ["Architecture"]),
    .library(name: "DependencyInjection", targets: ["DependencyInjection"]),
  ],
  targets: [
    .target(name: "Networker"),
    .target(name: "Storage"),
    .target(name: "Architecture"),
    .target(name: "DependencyInjection"),
    .testTarget(name: "DependencyInjectionTests", dependencies: ["DependencyInjection"]),
    .testTarget(name: "ArchitectureTests", dependencies: ["Architecture"]),
    .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    .testTarget(
      name: "NetworkerTests",
      dependencies: ["Networker"],
    ),
  ],
  swiftLanguageModes: [.v6],
)
