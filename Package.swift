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
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.3.0")
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["mongoc", "bson"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble"])
    ]
)
