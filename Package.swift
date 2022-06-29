// swift-tools-version:5.2

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
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.36.0")),
        .package(url: "https://github.com/mongodb/swift-bson", .upToNextMajor(from: "3.0.0"))
    ],
    targets: [
        .target(
            name: "MongoSwiftSync",
            dependencies: [
                "MongoSwift",
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwiftSync"]),
        .target(
            name: "TestsCommon",
            dependencies: [
                "MongoSwift",
                .product(name: "Nimble", package: "Nimble"),
            ]
        ),
        .testTarget(
            name: "BSONTests",
            dependencies: [
                "MongoSwift",
                "TestsCommon",
                "CLibMongoC",
                .product(name: "Nimble", package: "Nimble")
            ]
        ),
        .testTarget(
            name: "MongoSwiftTests",
            dependencies: [
                "MongoSwift",
                "TestsCommon",
                "Nimble",
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "MongoSwiftSyncTests",
            dependencies: [
                "MongoSwiftSync",
                "TestsCommon",
                "MongoSwift",
                .product(name: "Nimble", package: "Nimble")
            ]
        ),
        .target(
            name: "CLibMongoC",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("resolv"),
                .linkedLibrary("ssl", .when(platforms: [.linux])),
                .linkedLibrary("crypto", .when(platforms: [.linux])),
                .linkedLibrary("z", .when(platforms: [.linux]))
            ]
        )
    ]
)

#if compiler(>=5.3)
package.dependencies += [.package(url: "https://github.com/apple/swift-atomics", .upToNextMajor(from: "1.0.0"))]
package.targets += [
    .target(
        name: "MongoSwift",
        dependencies: [
            "CLibMongoC",
            .product(name: "Atomics", package: "swift-atomics"),
            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "SwiftBSON", package: "swift-bson")
        ]
    )
]
#else
package.targets += [
    .target(
        name: "MongoSwift",
        dependencies: [
            "CLibMongoC",
            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "SwiftBSON", package: "swift-bson")
        ]
    )
]
#endif
