#!/bin/bash
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

# this is set by drivers-matrix-testing, and it's a special variable used in swiftenv
# leaving it set messes with the installation
unset PLATFORM

export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"

# install swiftenv
git clone --depth 1 -b "osx-install-path" https://github.com/kmahar/swiftenv.git "${SWIFTENV_ROOT}"

# install swift
eval "$(swiftenv init -)"

if [ "$SWIFT_VERSION" = "main-snapshot" ]; then
    SWIFT_VERSION=$(swiftenv install --list-snapshots | tail -1)
fi

swiftenv install --install-local $SWIFT_VERSION
