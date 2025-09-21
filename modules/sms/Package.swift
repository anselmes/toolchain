// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-mcp-server",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "swift-mcp-server",
            targets: ["SwiftMCPServer"]
        ),
        .library(
            name: "SwiftZephyrTools",
            targets: ["SwiftZephyrTools"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftMCPServer",
            dependencies: [
                "SwiftZephyrTools",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "SwiftZephyrTools",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SwiftZephyrToolsTests",
            dependencies: ["SwiftZephyrTools"]
        )
    ]
)
