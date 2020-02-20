// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "VaporExample",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .exact("4.0.0-beta.3.24")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master"))
    ],
    targets: [
        .target(name: "VaporExample", dependencies: ["Vapor", "MongoSwift"])
    ]
)
