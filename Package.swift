// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "editor-bridge",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "EditorBridgeApp", targets: ["EditorBridgeApp"]),
    ],
    targets: [
        .executableTarget(
            name: "EditorBridgeApp",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
