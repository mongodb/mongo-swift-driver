// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "ssh://git@github.com/10gen/swift-bson", .branch("master")),
        .package(url: "ssh://git@github.com/10gen/swift-mongoc", .branch("master"))
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["libmongoc"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift"])
    ]
)

