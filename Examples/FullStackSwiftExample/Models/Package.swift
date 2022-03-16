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
        // TODO: Depend on a tag here.
        .package(url: "https://github.com/mongodb/swift-bson", .branch("main"))
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
