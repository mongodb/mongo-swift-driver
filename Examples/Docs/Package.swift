// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "DocsExamples",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master"))
    ],
    targets: [
        .target(name: "DocsExamples", dependencies: ["MongoSwift"])
    ]
)