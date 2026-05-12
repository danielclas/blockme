// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "steadfast",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SteadfastCore",
            targets: ["SteadfastCore"]
        ),
        .executable(
            name: "steadfast",
            targets: ["steadfast"]
        ),
        .executable(
            name: "blockme",
            targets: ["blockme"]
        ),
    ],
    targets: [
        .target(
            name: "SteadfastCore"
        ),
        .executableTarget(
            name: "steadfast",
            dependencies: ["SteadfastCore"]
        ),
        .executableTarget(
            name: "blockme",
            dependencies: ["SteadfastCore"]
        ),
        .testTarget(
            name: "SteadfastCoreTests",
            dependencies: ["SteadfastCore"]
        ),
    ]
)
