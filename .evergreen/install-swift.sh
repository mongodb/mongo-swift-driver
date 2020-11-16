#!/bin/sh
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.1.5}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"

# install swiftenv
git clone --depth 1 -b "osx-install-path" https://github.com/mbroadst/swiftenv.git "${SWIFTENV_ROOT}"

# install swift
eval "$(swiftenv init -)"
swiftenv install --install-local $SWIFT_VERSION
