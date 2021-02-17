#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

if ! command -v sourcekitten > /dev/null; then
  echo "ERROR: Failed to locate SourceKitten; please install yourself and/or add to your \$PATH"; exit 1
fi

version=${1}

# Ensure version is non-empty
[ ! -z "${version}" ] || { echo "ERROR: Missing version string"; exit 1; }

# obtain BSON version from Package.resolved
bson_version="$(python3 etc/get_bson_version.py)"

git clone --depth 1 --branch "v${bson_version}" https://github.com/mongodb/swift-bson
working_dir=${PWD}
cd swift-bson
sourcekitten doc --spm --module-name SwiftBSON > ${working_dir}/bson-docs.json
cd $working_dir

jazzy_args=(--clean
            --github-file-prefix https://github.com/mongodb/mongo-swift-driver/tree/v${version} 
            --module-version "${version}")

# Generate MongoSwift docs
sourcekitten doc --spm --module-name MongoSwift > mongoswift-docs.json
args=("${jazzy_args[@]}"  --output "docs-temp/MongoSwift" --module "MongoSwift" --config ".jazzy.yml" 
        --sourcekitten-sourcefile mongoswift-docs.json,bson-docs.json 
        --root-url "https://mongodb.github.io/mongo-swift-driver/docs/MongoSwift/")
jazzy "${args[@]}"

# Generate MongoSwiftSync docs

# we have to do some extra work to get re-exported symbols to show up
python3 etc/filter_sourcekitten_output.py

sourcekitten doc --spm --module-name MongoSwiftSync > mongoswiftsync-docs.json

args=("${jazzy_args[@]}"  --output "docs-temp/MongoSwiftSync" --module "MongoSwiftSync" --config ".jazzy.yml" 
        --sourcekitten-sourcefile mongoswift-filtered.json,mongoswiftsync-docs.json,bson-docs.json 
        --root-url "https://mongodb.github.io/mongo-swift-driver/docs/MongoSwiftSync/")
jazzy "${args[@]}"

rm -rf swift-bson
rm mongoswift-docs.json
rm mongoswift-filtered.json
rm mongoswiftsync-docs.json
rm bson-docs.json

echo '<html><head><meta http-equiv="refresh" content="0; url=MongoSwift/index.html" /></head></html>' > docs-temp/index.html

# we can only pass a single GitHub file prefix above, so we need to correct the BSON file paths throughout the docs.

# since we used the copy of BSON in .build/checkouts, look for all paths in that form throughout HTML files and replace them
# with the correct path to the BSON repo.
# note: we have to pass -print0 to `find` and pass -0 to `xargs` because some of the file names have spaces in them, which by
# default xargs will treat as a delimiter.
find docs-temp -name "*.html" -print0 | \
xargs -0 etc/sed.sh -i "s/mongo-swift-driver\/tree\/v${version}\/swift-bson/swift-bson\/tree\/v${bson_version}/"
