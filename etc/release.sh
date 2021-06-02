# usage: ./etc/release.sh [new version string]
# for example: ./etc/release.sh 1.0.0

# exit if any command fails
set -e

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# verify that the examples build
./etc/build-examples.sh

# regenerate documentation with new version string
./etc/generate-docs.sh ${version}

# commit/push docs to the gh-pages branch
git checkout gh-pages

rm -r docs/current
cp -r docs-temp docs/current
mv docs-temp docs/${version}

# build up documentation index
python3 ./_scripts/update-index.py

git add docs/
git commit -m "${version} docs"
git push

# go back to our original branch
git checkout -

# update version string for libmongoc handshake
sourcery --sources Sources/MongoSwift \
        --templates Sources/MongoSwift/MongoSwiftVersion.stencil \
        --output Sources/MongoSwift/MongoSwiftVersion.swift \
        --args versionString=${version}

# update the README with the version string
etc/sed.sh -i "s/mongo-swift-driver\", .upToNextMajor[^)]*)/mongo-swift-driver\", .upToNextMajor(from: \"${version}\")/" README.md

# commit changes
git add Sources/MongoSwift/MongoSwiftVersion.swift
git add README.md
git commit -m "${version}"

# tag release 
git tag "v${version}"

# push changes
git push
git push --tags

# go to GitHub to publish release notes
open "https://github.com/mongodb/mongo-swift-driver/releases/tag/v${version}"
