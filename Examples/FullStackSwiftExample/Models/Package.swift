// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "models",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Models",
            targets: ["Models"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/swift-bson", .upToNextMajor(from: "3.1.0"))
    ],
    targets: [
        .target(
            name: "Models",
            dependencies: [
                .product(name: "SwiftBSON", package: "swift-bson")
            ]
        )
    ]
)
