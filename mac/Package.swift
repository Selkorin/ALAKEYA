// swift-tools-version:5.9
import PackageDescription

// ALAKEYA native macOS host (DOC2: Swift + SwiftUI/AppKit + AXSwift +
// ScreenCaptureKit + Apple Speech). Builds the agent UI, permission flow and
// the semantic-first control cascade described in the production reports.
let package = Package(
    name: "Alakeya",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Swift wrapper over the C accessibility client APIs (DOC2 §AXSwift).
        .package(url: "https://github.com/tmandry/AXSwift.git", from: "0.3.2")
    ],
    targets: [
        .executableTarget(
            name: "Alakeya",
            dependencies: ["AXSwift"],
            path: "Sources/Alakeya",
            exclude: [
                "Overlay/AgentWorkspaceView.swift.bak"
            ],
            resources: [
                .copy("Core/Instructions"),
                .copy("Core/Skills"),
                .process("Resources/alakeya_logo.png"),
                .process("Resources/pers_1.png"),
                .process("Resources/ALAKEYA_logo_transparent.png"),
                .process("Resources/AppIcon.icns"),
                .process("Resources/log-al.png"),
                .process("Resources/logo.png"),
            ]
        ),
        .testTarget(
            name: "AlakeyaTests",
            dependencies: ["Alakeya"],
            path: "Tests/AlakeyaTests"
        )
    ]
)
