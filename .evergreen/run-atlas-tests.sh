#!/bin/sh
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.0.3}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
EXTRA_FLAGS="-Xlinker -rpath -Xlinker ${INSTALL_DIR}/lib"

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

swiftenv local $SWIFT_VERSION

# run the tests
ATLAS_REPL="$ATLAS_REPL" ATLAS_SHRD="$ATLAS_SHRD" ATLAS_FREE="$ATLAS_FREE" ATLAS_TLS11="$ATLAS_TLS11" ATLAS_TLS12="$ATLAS_TLS12" swift run AtlasConnectivity $EXTRA_FLAGS
