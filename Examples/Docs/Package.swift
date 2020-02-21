// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "DocsExamples",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.0.0"))
    ],
    targets: [
        .target(name: "SyncExamples", dependencies: ["MongoSwiftSync"]),
        .target(name: "AsyncExamples", dependencies: ["MongoSwift"])
    ]
)
