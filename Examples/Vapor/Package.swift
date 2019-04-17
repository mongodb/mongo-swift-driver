// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "VaporExample",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "3.3.0")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master"))
    ],
    targets: [
        .target(name: "VaporExample", dependencies: ["Vapor", "MongoSwift"])
    ]
)
