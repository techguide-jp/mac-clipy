// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacClipy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacClipy", targets: ["MacClipy"])
    ],
    targets: [
        .executableTarget(
            name: "MacClipy",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "MacClipyTests",
            dependencies: ["MacClipy"]
        )
    ]
)
