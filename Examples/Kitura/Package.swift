// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "KituraExample",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura", .upToNextMajor(from: "2.6.3")),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", .branch("master"))
    ],
    targets: [
        .target(name: "KituraExample", dependencies: ["Kitura", "MongoSwift"])
    ]
)
