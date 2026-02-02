// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tavern",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Tavern", targets: ["Tavern"]),
        .library(name: "TavernCore", targets: ["TavernCore"])
    ],
    dependencies: [
        // ClodeMonster's native Swift SDK
        .package(path: "/Users/yankee/Documents/Projects/ClodeMonster/NativeClaudeCodeSDK")
    ],
    targets: [
        // Core library - all logic, testable without UI
        .target(
            name: "TavernCore",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "NativeClaudeCodeSDK")
            ]
        ),

        // SwiftUI App
        .executableTarget(
            name: "Tavern",
            dependencies: ["TavernCore"],
            resources: [
                .process("Assets.xcassets"),
                .copy("AppIcon.icon")
            ]
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
