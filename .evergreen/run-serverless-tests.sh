#!/bin/bash

set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-5.2.5}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
INSTALL_DEPS=${INSTALL_DEPS:-"false"}

# if dependencies were not installed separately, do so now.
# this is used for continous matrix testing
if [ "$INSTALL_DEPS" == "true" ]; then
    SWIFT_VERSION=${SWIFT_VERSION} \
      sh ${PROJECT_DIRECTORY}/.evergreen/install-dependencies.sh
fi

# enable swiftenv
export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH="${SWIFTENV_ROOT}/bin:$PATH"
eval "$(swiftenv init -)"

# select the latest Xcode for Swift 5.1 support on MacOS
if [ "$OS" == "darwin" ]; then
    sudo xcode-select -s /Applications/Xcode11.3.app
fi

# switch swift version, and run tests
swiftenv local $SWIFT_VERSION

# build the driver
swift build

MONGODB_TOPOLOGY="sharded_cluster" \
  MONGODB_URI=${MONGODB_URI} \
  SINGLE_MONGOS_LB_URI=${SINGLE_MONGOS_LB_URI} \
  MULTI_MONGOS_LB_URI=${MULTI_MONGOS_LB_URI} \
  SERVERLESS="serverless" \
  MONGODB_API_VERSION=${MONGODB_API_VERSION} \
  MONGODB_SCRAM_USER=${SERVERLESS_ATLAS_USER} \
  MONGODB_SCRAM_PASSWORD=${SERVERLESS_ATLAS_PASSWORD} \
  AUTH="auth" \
  SSL="ssl" \
    swift test --filter="(Crud|Retryable|Transactions|Versioned|Session|LoadBalancer|MongoCursor)"
