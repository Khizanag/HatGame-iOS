// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HatGame-DesignBook",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "DesignBook",
            targets: ["DesignBook"]
        )
    ],
    targets: [
        .target(
            name: "DesignBook",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
