// swift-tools-version:5.1
import PackageDescription
let package = Package(
    name: "mongo-swift-driver",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"]),
        .library(name: "MongoSwiftSync", targets: ["MongoSwiftSync"])
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.15.0"))
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["CLibMongoC", "NIO", "NIOConcurrencyHelpers"]),
        .target(name: "MongoSwiftSync", dependencies: ["MongoSwift", "NIO"]),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwiftSync"]),
        .target(name: "TestsCommon", dependencies: ["MongoSwift", "Nimble"]),
        .testTarget(name: "BSONTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "CLibMongoC"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "NIO"]),
        .testTarget(name: "MongoSwiftSyncTests", dependencies: ["MongoSwiftSync", "TestsCommon", "Nimble", "MongoSwift"]),
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
