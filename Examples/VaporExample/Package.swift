// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "ComplexVaporExample",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.7.0")),
        .package(url: "https://github.com/vapor/leaf", .upToNextMajor(from: "4.0.0")),
        // TODO: update version once we release
        .package(url: "https://github.com/mongodb/mongodb-vapor", .branch("main"))
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
        .target(name: "Run", dependencies: [
            .target(name: "App"),
            .product(name: "MongoDBVapor", package: "mongodb-vapor")
        ])
    ]
)
