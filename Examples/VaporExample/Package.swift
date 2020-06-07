// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "VaporExample",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // The driver depends on SwiftNIO 2 and therefore is only compatible with Vapor 4.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.2.1"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(name: "VaporExample", dependencies: [
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            .product(name: "Vapor", package: "vapor"),
        ])
    ]
)
