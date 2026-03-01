// swift-tools-version: 6.0

import PackageDescription

// MARK: - Provenance: REQ-ARCH-001

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
        // Public interface — types, protocols, typealiases (zero ClodKit dependency)
        .target(
            name: "TavernKit",
            path: "Sources/TavernKit"
        ),

        // Leaf tiles (depend only on TavernKit)
        .target(
            name: "ApprovalTile",
            dependencies: ["TavernKit"],
            path: "Sources/Tiles/ApprovalTile"
        ),
        .target(
            name: "PermissionSettingsTile",
            dependencies: ["TavernKit"],
            path: "Sources/Tiles/PermissionSettingsTile"
        ),
        .target(
            name: "ServitorListTile",
            dependencies: ["TavernKit"],
            path: "Sources/Tiles/ServitorListTile"
        ),
        .target(
            name: "ResourcePanelTile",
            dependencies: ["TavernKit"],
            path: "Sources/Tiles/ResourcePanelTile"
        ),
        .target(
            name: "ChatTile",
            dependencies: ["TavernKit"],
            path: "Sources/Tiles/ChatTile"
        ),

        // Board tile (composes all leaf tiles)
        .target(
            name: "TavernBoardTile",
            dependencies: [
                "TavernKit",
                "ApprovalTile", "PermissionSettingsTile",
                "ServitorListTile", "ResourcePanelTile", "ChatTile",
            ],
            path: "Sources/Tiles/TavernBoardTile"
        ),

        // Core library — private implementation, imports ClodKit
        .target(
            name: "TavernCore",
            dependencies: [
                "TavernKit",
                .product(name: "ClodKit", package: "ClodKit")
            ]
        ),

        // SwiftUI App
        .executableTarget(
            name: "Tavern",
            dependencies: ["TavernCore", "TavernKit", "TavernBoardTile"],
            resources: [
                .process("Assets.xcassets"),
                .copy("AppIcon.icon")
            ]
        ),

        // Core tests
        .testTarget(
            name: "TavernCoreTests",
            dependencies: ["TavernCore", "TavernKit"]
        ),

        // App tests (UI wiring tests + integration tests)
        .testTarget(
            name: "TavernTests",
            dependencies: [
                "Tavern",
                "TavernCore",
                "TavernKit",
                "ChatTile",
                "ResourcePanelTile",
                .product(name: "ViewInspector", package: "ViewInspector")
            ]
        ),

        // Stress tests (slow, run before releases)
        .testTarget(
            name: "TavernStressTests",
            dependencies: ["TavernCore", "TavernKit"]
        ),

        // Integration tests (Grade 3 - real Claude API, headless)
        .testTarget(
            name: "TavernIntegrationTests",
            dependencies: ["TavernCore", "TavernKit"]
        )
    ]
)
