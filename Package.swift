// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "ssh://git@github.com/10gen/swift-bson", .branch("master")),
        .package(url: "ssh://git@github.com/10gen/swift-mongoc", .branch("master")),
        .package(url: "https://github.com/Quick/Quick.git", majorVersion: 1, minor: 2),
        .package(url: "https://github.com/Quick/Nimble.git", majorVersion: 7)
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["libmongoc"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift"])
    ]
)
