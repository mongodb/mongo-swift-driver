// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "VaporExample",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        // The driver depends on SwiftNIO 2 and therefore is only compatible with Vapor 4.
        .package(url: "https://github.com/vapor/vapor", .exact("4.0.0-beta.3.24")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.0.0-rc0"))
    ],
    targets: [
        .target(name: "VaporExample", dependencies: ["Vapor", "MongoSwift"])
    ]
)
