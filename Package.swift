// swift-tools-version:4.2
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/swift-bson", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/mongodb/swift-mongoc", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .exact("8.0.2"))
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["mongoc", "bson"]),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwift"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble", "mongoc"])
    ]
)
