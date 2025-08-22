// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TAPS",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "TAPS",
            targets: ["TAPS"]
        ),
        .executable(
            name: "TAPSExample",
            targets: ["TAPSExample"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.86.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "TAPS",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/TAPS"
        ),
        .executableTarget(
            name: "TAPSExample",
            dependencies: ["TAPS",
                           .product(name: "ArgumentParser", package: "swift-argument-parser")
                          ],
            path: "Sources/TAPSExample"
        ),
        .testTarget(
            name: "TAPSTests",
            dependencies: ["TAPS"],
            path: "Tests/TAPSTests"
        ),
    ]
)
