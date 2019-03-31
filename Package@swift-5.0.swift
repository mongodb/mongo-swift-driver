// swift-tools-version:5.0
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/swift-bson", .branch("SWIFT-276/swift-5-support")),
        .package(url: "https://github.com/mongodb/swift-mongoc", from: "2.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.1")
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["mongoc", "bson"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble"])
    ]
)
