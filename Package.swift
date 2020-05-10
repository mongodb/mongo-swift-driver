// swift-tools-version:5.1
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble.git", .exact("8.0.2"))
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["mongoc", "bson"]),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwift"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble", "mongoc"]),
        .systemLibrary(
            name: "mongoc",
            pkgConfig: "libmongoc-1.0",
            providers: [
                .brew(["mongo-c-driver"]),
                .apt(["libmongoc-dev"])
            ]
        ),
        .systemLibrary(
            name: "bson",
            pkgConfig: "libbson-1.0",
            providers: [
                .brew(["mongo-c-driver"]),
                .apt(["libbson-dev"])
            ]
        )
    ]
)
