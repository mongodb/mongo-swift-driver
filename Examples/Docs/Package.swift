// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "DocsExamples",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch(from: "master"))
    ],
    targets: [
        .target(name: "SyncExamples", dependencies: ["MongoSwiftSync"]),
        .target(name: "AsyncExamples", dependencies: ["MongoSwift"])
    ]
)
