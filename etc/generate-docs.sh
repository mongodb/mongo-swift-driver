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

# ensure we have fresh build data for the docs generation process
rm -rf .build

# obtain BSON version from Package.resolved
bson_version="$(python3 etc/get_bson_version.py)"

git clone --depth 1 --branch "v${bson_version}" https://github.com/mongodb/swift-bson
working_dir=${PWD}
cd swift-bson
sourcekitten doc --spm --module-name SwiftBSON > ${working_dir}/bson-docs.json
cd $working_dir

mkdir Guides-Temp
cp Guides/*.md Guides-Temp/
cp swift-bson/Guides/*.md Guides-Temp/

jazzy_args=(--clean
            --github-file-prefix https://github.com/mongodb/mongo-swift-driver/tree/v${version} 
            --module-version "${version}"
            --documentation "Guides-Temp/*.md"
          )

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
rm -rf Guides-Temp

echo '<html><head><meta http-equiv="refresh" content="0; url=MongoSwift/index.html" /></head></html>' > docs-temp/index.html

# we can only pass a single GitHub file prefix above, so we need to correct the BSON file paths throughout the docs.

# Jazzy generates the links for each file by taking the base path we provide above as --github-file-prefix and tacking on
#  the path of each file relative to the project's root directory. since we check out swift-bson from the root of the driver,
# all of the generated URLs for BSON symbols are of the form
# ....mongo-swift-driver/tree/v[driver version]/swift-bson/...
# Here we replace all occurrences of this with the correct GitHub root URL, swift-bson/tree/v[bson version].
# note: we have to pass -print0 to `find` and pass -0 to `xargs` because some of the file names have spaces in them, which by
# default xargs will treat as a delimiter.
find docs-temp -name "*.html" -print0 | \
xargs -0 etc/sed.sh -i "s/mongo-swift-driver\/tree\/v${version}\/swift-bson/swift-bson\/tree\/v${bson_version}/"
