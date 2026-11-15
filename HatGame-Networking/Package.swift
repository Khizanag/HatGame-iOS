// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HatGame-Networking",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "GameCore"
        ),
        .target(
            name: "Networking",
            dependencies: [
                "GameCore",
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
