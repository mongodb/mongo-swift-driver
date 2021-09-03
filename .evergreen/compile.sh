#!/bin/bash
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
SWIFT_VERSION=${SWIFT_VERSION:-5.4.2}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

if [ "$OS" == "darwin" ]; then
    # 5.1, 5.2 require an older version of Xcode/Command Line Tools
    if [[ "$SWIFT_VERSION" == 5.1.* || "$SWIFT_VERSION" == 5.2.* ]]; then
        sudo xcode-select -s /Applications/Xcode11.3.app
    else
        sudo xcode-select -s /Applications/Xcode12.app
    fi
fi

# switch swift version and build
swiftenv local $SWIFT_VERSION
swift build
