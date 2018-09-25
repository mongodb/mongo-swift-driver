// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "KituraExample",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.2.0"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver", from: "0.0.3")
    ],
    targets: [
        .target(name: "KituraExample", dependencies: ["Kitura", "MongoSwift"])
    ]
)
