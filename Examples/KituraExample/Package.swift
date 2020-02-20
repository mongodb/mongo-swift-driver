// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "KituraExample",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura", .upToNextMajor(from: "2.9.1")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master")),
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.14.0"))
    ],
    targets: [
        .target(name: "KituraExample", dependencies: ["Kitura", "MongoSwift", "NIO"])
    ]
)
