// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "PerfectExample",
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "0.1.0")),
    ],
    targets: [
        .target(name: "PerfectExample", dependencies: ["PerfectHTTPServer", "MongoSwift"])
    ]
)
