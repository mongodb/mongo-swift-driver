#!/bin/bash

set -o xtrace
set -o errexit  # Exit the script with error if any of the commands fail

# Required environment variables:
# MONGODB_URI
# OCSP_TLS_SHOULD_SUCCEED    Whether the connection attempt should succeed or not with
#                            the given configuration.
# OCSP_ALGORITHM             Specify the cyptographic algorithm used to sign the server's
#                            certificate. Must be either "rsa" or "ecdsa".

echo "Running OCSP test"

# show test output
set -x

# variables
export MONGODB_URI=${MONGODB_URI:-"NO_URI_PROVIDED"}
export SSL=ssl
export SSL_CA_FILE="$DRIVERS_TOOLS/.evergreen/ocsp/${OCSP_ALGORITHM}/ca.pem"
export MONGODB_OCSP_TESTING=1
export OCSP_ALGORITHM=${OCSP_ALGORITHM}
export OCSP_TLS_SHOULD_SUCCEED=${OCSP_TLS_SHOULD_SUCCEED}
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.2.5}
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

# switch swift version, and run tests
swiftenv local $SWIFT_VERSION

# build the driver
swift build

# test the driver
set +o errexit # even if tests fail we want to parse the results, so disable errexit
set -o pipefail # propagate error codes in the following pipes

swift test --filter=OCSP
