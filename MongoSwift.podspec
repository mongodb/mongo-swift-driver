Pod::Spec.new do |spec|
  spec.name       = "MongoSwift"
  spec.version    = "0.0.1"
  spec.summary    = "The Swift driver for MongoDB"
  spec.homepage   = "https://github.com/mongodb/mongo-swift-driver"
  spec.license    = 'AGPL 3.0'
  spec.authors    = {
    "Matt Broadstone" => "mbroadst@mongodb.com",
    "Kaitlin Mahar" => "kaitlin.mahar@mongodb.com"
  }
  spec.source     = {
    :git => "https://github.com/mongodb/mongo-swift-driver.git",
    :branch => "master"
  }

  spec.ios.deployment_target = "11.2"
  spec.tvos.deployment_target = "9.1"
  spec.osx.deployment_target = "10.10"

  spec.swift_version = "4"
  spec.requires_arc = true
  spec.source_files = "Sources/MongoSwift/**/*.swift"
  spec.preserve_paths = [
    "Sources/libbson/*.{h,modulemap}",
    "Sources/libmongoc/*.{h,modulemap}"
  ]

  # checkout module definitions for libmongoc and libbson
  spec.prepare_command = <<-EOT
  [[ -d Sources/libbson ]] || git clone --depth 1 https://github.com/mongodb/swift-bson Sources/libbson
  [[ -d Sources/libmongoc ]] || git clone --depth 1 https://github.com/mongodb/swift-mongoc Sources/libmongoc
  EOT

  # dynamically find paths for libmongoc
  mongoc_paths = {
    "include" => `pkg-config libmongoc-1.0 --cflags-only-I`.chomp!.split(' ').map { |path| "\"#{path.sub(/-I/, '')}\"" }.join(' '),
    "library" => `pkg-config libmongoc-1.0 --libs-only-L`.chomp!.split(' ').map { |path| "\"#{path.sub(/-L/, '')}\"" }.join(' ')
  }

  spec.pod_target_xcconfig = {
    "SWIFT_INCLUDE_PATHS" => [
      '"$(PODS_TARGET_SRCROOT)/Sources/libbson"',
      '"$(PODS_TARGET_SRCROOT)/Sources/libmongoc"',
      mongoc_paths['include']
    ].join(' '),
    "LIBRARY_SEARCH_PATHS" => mongoc_paths["library"]
  }

  spec.user_target_xcconfig = {
    "LIBRARY_SEARCH_PATHS" => mongoc_paths["library"]
  }
end
