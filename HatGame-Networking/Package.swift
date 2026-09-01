// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HatGame-Networking",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
