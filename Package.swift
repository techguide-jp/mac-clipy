// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClipy",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacClipy", targets: ["MacClipy"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.8")
    ],
    targets: [
        .executableTarget(
            name: "MacClipy",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "Defaults", package: "Defaults")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacClipyTests",
            dependencies: [
                "MacClipy",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Defaults", package: "Defaults")
            ]
        )
    ]
)
