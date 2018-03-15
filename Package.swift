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
        //.package(url: "https://github.com/Quick/Quick.git", from: "1.2.0"),
        .package(url: "../Quick", .branch("test")),
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.0.3")
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["libmongoc"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble", "Quick"])
        //.testTarget(name: "MongoSwiftBenchmarks", dependencies: ["MongoSwift"])
    ]
)
