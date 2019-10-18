// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "BugReport",
    dependencies: [
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: ["MongoSwift"]
        )
    ]
)
