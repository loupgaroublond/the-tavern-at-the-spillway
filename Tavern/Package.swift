// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tavern",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Tavern", targets: ["Tavern"]),
        .library(name: "TavernCore", targets: ["TavernCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK.git", from: "1.0.0")
    ],
    targets: [
        // Core library - all logic, testable without UI
        .target(
            name: "TavernCore",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")
            ]
        ),

        // SwiftUI App
        .executableTarget(
            name: "Tavern",
            dependencies: ["TavernCore"]
        ),

        // Core tests
        .testTarget(
            name: "TavernCoreTests",
            dependencies: ["TavernCore"]
        ),

        // App tests (UI tests if needed)
        .testTarget(
            name: "TavernTests",
            dependencies: ["Tavern", "TavernCore"]
        ),

        // Stress tests (slow, run before releases)
        .testTarget(
            name: "TavernStressTests",
            dependencies: ["TavernCore"]
        )
    ]
)
