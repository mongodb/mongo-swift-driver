// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "PerfectExample",
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.14.0"))
    ],
    targets: [
        .target(name: "PerfectExample", dependencies: ["PerfectHTTPServer", "MongoSwift"])
    ]
)
