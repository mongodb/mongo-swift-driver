#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

if ! command -v sourcekitten > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate SourceKitten; please install yourself"; exit 1; }
fi

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

jazzy_args=(--clean
            --github-file-prefix https://github.com/mongodb/mongo-swift-driver/tree/v${version} 
            --module-version "${version}")

# Generate MongoSwift docs
args=("${jazzy_args[@]}"  --output "docs-temp/MongoSwift" --module "MongoSwift" --config ".jazzy.yml" 
        --root-url "https://mongodb.github.io/mongo-swift-driver/docs/MongoSwift/")
jazzy "${args[@]}"

# Generate MongoSwiftSync docs

# we have to do some extra work to get re-exported symbols to show up
sourcekitten doc --spm --module-name MongoSwift > mongoswift-docs.json
python3 etc/filter_sourcekitten_output.py

sourcekitten doc --spm --module-name MongoSwiftSync > mongoswiftsync-docs.json

args=("${jazzy_args[@]}"  --output "docs-temp/MongoSwiftSync" --module "MongoSwiftSync" --config ".jazzy.yml" 
        --sourcekitten-sourcefile mongoswift-filtered.json,mongoswiftsync-docs.json
        --root-url "https://mongodb.github.io/mongo-swift-driver/docs/MongoSwiftSync/")
jazzy "${args[@]}"

rm mongoswift-docs.json
rm mongoswift-filtered.json
rm mongoswiftsync-docs.json

# git checkout gh-pages

# rm -rf docs/*
# cp -r docs-temp/* docs/
# rm -rf docs-temp

# echo '<html><head><meta http-equiv="refresh" content="0; url=MongoSwift/index.html" /></head></html>' > docs/index.html

# git add docs/

# git commit -m "${version} docs"
# git push

# # go back to wherever we started
# git checkout -
