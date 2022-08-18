#!/bin/bash

set -eu

executable=$1

target=.build/lambda/$executable
rm -rf "$target"
mkdir -p "$target"
cp ".build/release/$executable" "$target/"
cd "$target"
ln -s "$executable" "bootstrap"
zip --symlinks lambda.zip *
