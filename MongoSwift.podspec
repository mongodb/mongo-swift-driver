Pod::Spec.new do |spec|
  spec.name       = "MongoSwift"
  spec.version    = "0.0.1"
  spec.summary    = "Some description"
  spec.homepage   = "https://github.com/10gen/mongo-swift-driver"
  spec.license    = 'Apache License 2.0'
  spec.author     = { "mbroadst" => "mbroadst@mongodb.com" }
  spec.source     = {
    :git => "ssh://git@github.com/10gen/mongo-swift-driver.git",
    :branch => "master"
  }

  spec.swift_version = "4"
  spec.requires_arc = true
  spec.source_files = "Sources/MongoSwift/**/*.swift"
  spec.preserve_paths = [
    "Sources/libbson/*.{h,modulemap}",
    "Sources/libmongoc/*.{h,modulemap}"
  ]

  # checkout module definitions for libmongoc and libbson
  spec.prepare_command = <<-EOT
  git clone --depth 1 ssh://git@github.com/10gen/swift-bson Sources/libbson
  git clone --depth 1 ssh://git@github.com/10gen/swift-mongoc Sources/libmongoc
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
