// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "VaporExample",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.50.0")),
        .package(url: "https://github.com/vapor/leaf", .upToNextMajor(from: "4.0.0")),
        .package(url: "https://github.com/mongodb/mongodb-vapor", .branch("async-await"))
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "MongoDBVapor", package: "mongodb-vapor")
            ]
        ),
        .executableTarget(name: "Run", dependencies: [
            .target(name: "App"),
            .product(name: "MongoDBVapor", package: "mongodb-vapor")
        ])
    ]
)
