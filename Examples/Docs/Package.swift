// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "DocsExamples",
    platforms: [
        .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("main")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(name: "SyncExamples", dependencies: ["MongoSwiftSync"]),
        .target(name: "AsyncExamples", dependencies: ["MongoSwift", "NIO"])
    ]
)
