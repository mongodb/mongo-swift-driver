#!/bin/bash

set -o errexit  # Exit the script with error if any of the commands fail

# variables
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
INSTALL_DEPS=${INSTALL_DEPS:-"false"}

# if dependencies were not installed separately, do so now.
# this is used for continous matrix testing
if [ "$INSTALL_DEPS" == "true" ]; then
    SWIFT_VERSION=${SWIFT_VERSION} \
      sh ${PROJECT_DIRECTORY}/.evergreen/install-dependencies.sh
fi

# configure Swift
. ${PROJECT_DIRECTORY}/.evergreen/configure-swift.sh

# build the driver
swift build

MONGODB_TOPOLOGY="load_balanced" \
  MONGODB_URI=${MONGODB_URI} \
  SINGLE_MONGOS_LB_URI=${SINGLE_MONGOS_LB_URI} \
  MULTI_MONGOS_LB_URI=${MULTI_MONGOS_LB_URI} \
  SERVERLESS="serverless" \
  MONGODB_API_VERSION=${MONGODB_API_VERSION} \
  MONGODB_SCRAM_USER=${SERVERLESS_ATLAS_USER} \
  MONGODB_SCRAM_PASSWORD=${SERVERLESS_ATLAS_PASSWORD} \
  AUTH="auth" \
  SSL="ssl" \
    swift test --enable-test-discovery --filter="(Crud|Retryable|Transactions|Versioned|Session|LoadBalancer|MongoCursor)"
