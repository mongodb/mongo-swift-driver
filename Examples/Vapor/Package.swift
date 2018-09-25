// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "VaporExample",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", from: "0.0.3")
    ],
    targets: [
        .target(name: "VaporExample", dependencies: ["Vapor", "MongoSwift"])
    ]
)

