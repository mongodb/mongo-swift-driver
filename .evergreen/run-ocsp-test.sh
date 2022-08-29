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
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"

# configure Swift
. ${PROJECT_DIRECTORY}/.evergreen/configure-swift.sh


# work around https://github.com/mattgallagher/CwlPreconditionTesting/issues/22 (bug still exists in version 1.x
# when using Xcode 13.2)
if [ "$OS" == "darwin" ]; then
    EXTRA_FLAGS="-Xswiftc -Xfrontend -Xswiftc -validate-tbd-against-ir=none"
fi

# build the driver
swift build $EXTRA_FLAGS

# test the driver
set +o errexit # even if tests fail we want to parse the results, so disable errexit
set -o pipefail # propagate error codes in the following pipes

swift test --enable-test-discovery $EXTRA_FLAGS --filter=OCSP
