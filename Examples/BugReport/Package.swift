// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "BugReport",
    dependencies: [
         .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master"))
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: ["MongoSwift"])
    ]
)
