Pod::Spec.new do |spec|
  spec.name       = "MongoSwift"
  spec.version    = "0.1.0"
  spec.summary    = "The Swift driver for MongoDB"
  spec.homepage   = "https://github.com/mongodb/mongo-swift-driver"
  spec.license    = 'Apache License, Version 2.0'
  spec.authors    = {
    "Matt Broadstone" => "mbroadst@mongodb.com",
    "Kaitlin Mahar" => "kaitlin.mahar@mongodb.com",
    "Patrick Freed" => "patrick.freed@mongodb.com"
  }

  spec.source     = {
    :git => "https://github.com/mongodb/mongo-swift-driver.git",
    :tag => 'v0.1.0'
  }

  spec.osx.deployment_target = "10.12"
  spec.ios.deployment_target = "11.0"
  spec.tvos.deployment_target = "10.2"
  spec.watchos.deployment_target = "4.3"

  spec.requires_arc = true
  spec.source_files = "Sources/MongoSwift/**/*.swift"

  spec.dependency 'mongo-embedded-c-driver', '~> 1.13.0-4.0.0'
end
