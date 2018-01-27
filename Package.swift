import PackageDescription

let package = Package(
  name: "MongoSwift",
  targets: [
    Target(name: "libmongoc",
           dependencies: ["libbson"]),
    Target(name: "MongoSwift",
           dependencies: ["libmongoc"])
  ]
)

