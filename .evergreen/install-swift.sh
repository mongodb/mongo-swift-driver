#!/bin/sh
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.1.5}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

# this is set by drivers-matrix-testing, and it's a special variable used in swiftenv
# leaving it set messes with the installation
unset PLATFORM

export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"

# install swiftenv
git clone --depth 1 https://github.com/kylef/swiftenv.git "${SWIFTENV_ROOT}"

# install swift
eval "$(swiftenv init -)"

if [[ $SWIFT_VERSION == "main-snapshot" ]]
then
    SWIFT_VERSION=$(swiftenv install --list-snapshots | tail -1)
fi

swiftenv install --user $SWIFT_VERSION
