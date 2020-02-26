#!/bin/bash

# usage: ./etc/generate-docs.sh [new version string]

# exit if any command fails
set -e

if ! command -v jazzy > /dev/null; then
  gem install jazzy || { echo "ERROR: Failed to locate or install jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
fi

version=${1}

jazzy_args=(--clean
            --author 'Matt Broadstone, Kaitlin Mahar, and Patrick Freed' 
            --readme "docs/README.md" 
            --author_url https://github.com/mongodb/mongo-swift-driver 
            --github_url https://github.com/mongodb/mongo-swift-driver 
            --theme fullwidth 
            --documentation "Guides/*.md" 
            --github-file-prefix https://github.com/mongodb/mongo-swift-driver/tree/v${version} 
            --module-version "${version}" 
            --swift-build-tool spm)

modules=( MongoSwift MongoSwiftSync )

for module in "${modules[@]}"; do
  args=("${jazzy_args[@]}"  --output "docs/${module}" --module "${module}" 
        --root-url "https://mongodb.github.io/mongo-swift-driver/docs/${module}/")
  jazzy "${args[@]}"
done
