// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AWSLambdaExample",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(
            url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/mongodb/mongo-swift-driver",
            .upToNextMajor(from: "1.0.0")
        )
    ],
    targets: [
        .executableTarget(
            name: "AWSLambdaExample",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "MongoSwift", package: "mongo-swift-driver")
            ]
        ),
    ]
)
