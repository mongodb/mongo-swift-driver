// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "VaporExample",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "3.3.0")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(name: "VaporExample", dependencies: ["Vapor", "MongoSwift"])
    ]
)
