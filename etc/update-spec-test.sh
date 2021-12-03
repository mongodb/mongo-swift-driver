#!/usr/bin/env bash

# This script is used to fetch the latest version of a JSON test from the specification repository
# You can pass it the relative path to a spec file and it will fetch the latest version of the test
# Example usage from driver root directory: 
# $ ./etc/update-spec-test.sh crud/tests/unified/deleteMany-let.json

set -o errexit
set -o nounset

if [ ! -d ".git" ]; then
    echo "$0: This script must be run from the root of the repository" >&2
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "$0: This script must be passed exactly one argument for which test to sync" >&2
    exit 1
fi

spec_root="Tests/Specs"

tmpdir=`perl -MFile::Temp=tempdir -wle 'print tempdir(TMPDIR => 1, CLEANUP => 0)'`
curl -sL https://github.com/mongodb/specifications/archive/master.zip -o "$tmpdir/specs.zip"
unzip -d "$tmpdir" "$tmpdir/specs.zip" > /dev/null

touch "$spec_root/$1"
rsync -ah "$tmpdir/specifications-master/source/$1" "$spec_root/$1" --delete

rm -rf "$tmpdir"
