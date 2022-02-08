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
    dependencies: getDependencies(),
    targets: [
        .target(name: "MongoSwift", dependencies: getMongoSwiftDependencies()),
        .target(name: "MongoSwiftSync", dependencies: ["MongoSwift", "NIO"]),
        .target(name: "AtlasConnectivity", dependencies: ["MongoSwiftSync"]),
        .target(name: "TestsCommon", dependencies: ["MongoSwift", "Nimble"]),
        .testTarget(name: "BSONTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "CLibMongoC"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "TestsCommon", "Nimble", "NIO", "NIOConcurrencyHelpers"]),
        .testTarget(name: "MongoSwiftSyncTests", dependencies: ["MongoSwiftSync", "TestsCommon", "Nimble", "MongoSwift"]),
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

func getDependencies() -> [PackageDescription.Package.Dependency] {
    var packages: [PackageDescription.Package.Dependency] = [
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.15.0")),
        .package(url: "https://github.com/mongodb/swift-bson", .upToNextMajor(from: "3.0.0"))
    ]
#if compiler(>=5.3)
    packages.append(.package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.0")))
#endif
    return packages
}

func getMongoSwiftDependencies() -> [Target.Dependency] {
    var dependencies: [Target.Dependency] = ["CLibMongoC", "NIO", "NIOConcurrencyHelpers", "SwiftBSON"]
#if compiler(>=5.3)
    dependencies.append("Atomics")
#endif
    return dependencies
}
