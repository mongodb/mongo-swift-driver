# usage: ./release/release.sh [new version string]
# for example: ./release/release.sh 1.0.0

# exit if any command fails
set -e

# update version string for libmongoc handshake
sourcery --sources Sources/MongoSwift --templates Sources/MongoSwift/MongoSwiftVersion.stencil --output Sources/MongoSwift/MongoSwiftVersion.swift --args versionString=${1}

# regenerate documentation with new version string
export DOCSVERSION=${1}
make documentation

# commit changes
git add docs/
git add Sources/MongoSwift/MongoSwiftVersion.swift
git commit -m "${1}"

# tag release 
git tag "v${1}"

# push changes
git push
git push --tags

# go to GitHub to publish release notes
open "https://github.com/mongodb/mongo-swift-driver/releases/tag/v${1}"
