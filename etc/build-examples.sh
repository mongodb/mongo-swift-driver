#!/bin/sh

examples=("BugReport" "Docs" "KituraExample" "PerfectExample" "VaporExample")

for example_project in ${examples[@]}; do
    echo "Building $example_project"
    pushd "Examples/$example_project"
    swift build
    build_success=$?

    rm -rf ./.build
    rm Package.resolved
    popd

    if [ ${build_success} -eq 0 ]; then
        echo "================= Building $example_project succeeded ================="
    else
        echo "================= Building $example_project failed ================="
        exit 1
    fi
done
