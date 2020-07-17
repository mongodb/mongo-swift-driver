#!/bin/bash

exit_code=0

examples=("BugReport" "Docs" "KituraExample" "PerfectExample" "VaporExample" "Atlas")

for example_project in ${examples[@]}; do
    echo "Building $example_project"
    example_dir="Examples/${example_project}"

    # replace version string with master
    etc/sed.sh -i 's/swift-driver", .upToNextMajor[^)]*)/swift-driver", .branch("master")/' "${example_dir}/Package.swift"

    pushd "${example_dir}"

    # don't exit on failure
    set +e
    if [ ${example_project} == "KituraExample" ]; then
        export KITURA_NIO=1
    fi
    swift build
    build_success=$?
    set -e

    rm -rf ./.build
    rm Package.resolved
    git checkout Package.swift
    popd

    if [ ${build_success} -eq 0 ]; then
        echo "================= Building $example_project succeeded ================="
    else
        echo "================= Building $example_project failed ================="
        exit_code=1
    fi
done

exit "${exit_code}"
