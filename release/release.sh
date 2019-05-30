# usage: ./release/release.sh [new version string]
# for example: ./release/release.sh 1.0.0

# update version string for libmongoc handshake
sourcery --sources Sources/MongoSwift --templates Sources/MongoSwift/MongoSwiftVersion.stencil --output Sources/MongoSwift/MongoSwiftVersion.swift --args versionString=${1}

# regenerate documentation with new version string
export DOCSVERSION=${1}
make documentation

# commit changes
git add docs/
git add Sources/MongoSwift/MongoSwift.swift
git commit -m "${1}"

# tag release 
git tag "v${1}"

# push changes
git push --tags

# update podspec
cat > ${PWD}/MongoSwift.podspec <<- EOF
Pod::Spec.new do |spec|
  spec.name       = "MongoSwift"
  spec.version    = "${1}"
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
    :tag => 'v${1}'
  }

  spec.ios.deployment_target = "11.0"
  spec.tvos.deployment_target = "10.2"
  spec.watchos.deployment_target = "4.3"

  spec.requires_arc = true
  spec.source_files = "Sources/MongoSwift/**/*.swift"

  spec.dependency 'mongo-embedded-c-driver', '~> 1.13.0-4.0.0'
end
EOF

# publish new podspec
pod trunk push ${PWD}/MongoSwift.podspec

# cleanup podspec
rm ${PWD}/MongoSwift.podspec

# go to GitHub to publish release notes
open "https://github.com/mongodb/mongo-swift-driver/releases/tag/v${1}"
