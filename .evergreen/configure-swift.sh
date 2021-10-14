#!/bin/bash

# This script sets up the required version of Swift correctly using swiftenv.
# This script should be run as:
# . path-to-script/configure-swift.sh
# So that its commands are run within the calling context and the script can
# properly set environment variables used there.

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
INSTALL_DIR=${INSTALL_DIR:-"MISSING_INSTALL_DIR"}

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

# dynamically determine latest available snapshot if needed
if [ "$SWIFT_VERSION" = "main-snapshot" ]; then
    SWIFT_VERSION=$(swiftenv install --list-snapshots | tail -1)
fi

if [ "$OS" == "darwin" ]; then
    # 5.1, 5.2 require an older version of Xcode/Command Line Tools
    if [[ "$SWIFT_VERSION" == 5.1.* || "$SWIFT_VERSION" == 5.2.* ]]; then
        sudo xcode-select -s /Applications/Xcode11.3.app
    else
        sudo xcode-select -s /Applications/Xcode12.app
    fi
fi

# switch to current Swift version
swiftenv local $SWIFT_VERSION
