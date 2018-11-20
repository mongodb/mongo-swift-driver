// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "BugReport",
    dependencies: [
         .package(url: "https://github.com/mongodb/mongo-swift-driver", from: "0.0.3")
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: ["MongoSwift"])
    ]
)
