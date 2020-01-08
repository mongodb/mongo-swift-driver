// swift-tools-version:5.0
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"]),
        .library(name: "MongoSwiftSync", targets: ["MongoSwiftSync"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble.git", .exact("8.0.2")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["CLibMongoC", "NIO"]),
        .target(name: "MongoSwiftSync", dependencies: ["MongoSwift"]),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwiftSync"]),
        .target(name: "TestsCommon", dependencies: ["MongoSwift", "MongoSwiftSync", "Nimble", "CLibMongoC"]),
        .testTarget(name: "BSONTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "CLibMongoC"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "NIO", "CLibMongoC"]),
        .testTarget(name: "MongoSwiftSyncTests", dependencies: ["MongoSwiftSync", "TestsCommon", "Nimble", "CLibMongoC"]),
        .target(
            name: "CLibMongoC",
            dependencies: [],
            cSettings: [
                .define("MONGO_SWIFT_OS_LINUX", .when(platforms: [.linux])),
                .define("MONGO_SWIFT_OS_DARWIN", .when(platforms: [.macOS])),
                .define("BSON_COMPILATION"),
                .define("MONGOC_COMPILATION")
            ],
            linkerSettings: [
                .linkedLibrary("resolv"),
                .linkedLibrary("ssl", .when(platforms: [.linux])),
                .linkedLibrary("crypto", .when(platforms: [.linux])),
                .linkedLibrary("z", .when(platforms: [.linux]))
            ]
        )
    ]
)
