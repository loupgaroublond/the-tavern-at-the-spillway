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
        // ClodKit SDK
        .package(url: "https://github.com/loupgaroublond/ClodKit", from: "1.0.0"),
        // ViewInspector for SwiftUI view-ViewModel wiring tests
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
    ],
    targets: [
        // Core library - all logic, testable without UI
        .target(
            name: "TavernCore",
            dependencies: [
                .product(name: "ClodKit", package: "ClodKit")
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

        // App tests (UI wiring tests + integration tests)
        .testTarget(
            name: "TavernTests",
            dependencies: [
                "Tavern",
                "TavernCore",
                .product(name: "ViewInspector", package: "ViewInspector")
            ]
        ),

        // Stress tests (slow, run before releases)
        .testTarget(
            name: "TavernStressTests",
            dependencies: ["TavernCore"]
        ),

        // Integration tests (Grade 3 - real Claude API, headless)
        .testTarget(
            name: "TavernIntegrationTests",
            dependencies: ["TavernCore"]
        )
    ]
)
