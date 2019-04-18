// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "KituraExample",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura", .upToNextMajor(from: "2.6.3")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(name: "KituraExample", dependencies: ["Kitura", "MongoSwift"])
    ]
)
