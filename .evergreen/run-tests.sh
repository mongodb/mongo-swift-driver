#!/bin/sh
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
MONGODB_URI=${MONGODB_URI:-"NO_URI_PROVIDED"}
SWIFT_VERSION=${SWIFT_VERSION:-4.2}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
TOPOLOGY=${TOPOLOGY:-single}
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

# switch swift version, and run tests
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig"

# override where we look for libmongoc
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib"
export DYLD_LIBRARY_PATH="${INSTALL_DIR}/lib"

swiftenv local $SWIFT_VERSION
MONGODB_TOPOLOGY=${TOPOLOGY} MONGODB_URI=$MONGODB_URI make test
