// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "DocsExamples",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(name: "SyncExamples", dependencies: ["MongoSwiftSync"]),
        .target(name: "AsyncExamples", dependencies: ["MongoSwift", "NIO"])
    ]
)
