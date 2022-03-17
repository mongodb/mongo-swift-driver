// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Backend",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMajor(from: "4.50.0")),
        .package(url: "https://github.com/mongodb/mongodb-vapor", .exact("1.1.0-beta.1")),
        .package(path: "../Models")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "MongoDBVapor", package: "mongodb-vapor"),
                .product(name: "Models", package: "models")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. For details, see
                // <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production>.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [
            .target(name: "App"),
            .product(name: "MongoDBVapor", package: "mongodb-vapor")
        ])
    ]
)
