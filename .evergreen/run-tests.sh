#!/bin/bash
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-"MISSING_PROJECT_DIRECTORY"}
MONGODB_URI=${MONGODB_URI:-"NO_URI_PROVIDED"}
SINGLE_MONGOS_LB_URI=${SINGLE_MONGOS_LB_URI:-"NO_URI_PROVIDED"}
MULTI_MONGOS_LB_URI=${MULTI_MONGOS_LB_URI:-"NO_URI_PROVIDED"}
SWIFT_VERSION=${SWIFT_VERSION:-"MISSING_SWIFT_VERSION"}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
TOPOLOGY=${TOPOLOGY:-single}
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
RAW_TEST_RESULTS="${PROJECT_DIRECTORY}/rawTestResults"
XML_TEST_RESULTS="${PROJECT_DIRECTORY}/testResults.xml"
INSTALL_DEPS=${INSTALL_DEPS:-"false"}
TEST_FILTER=${TEST_FILTER:-"NO_FILTER"}
SANITIZE=${SANITIZE:-"false"}

# ssl setup
SSL=${SSL:-nossl}
if [ "$SSL" != "nossl" ]; then
   export SSL_KEY_FILE="$DRIVERS_TOOLS/.evergreen/x509gen/client.pem"
   export SSL_CA_FILE="$DRIVERS_TOOLS/.evergreen/x509gen/ca.pem"
fi

# if dependencies were not installed separately, do so now.
# this is used for continous matrix testing
if [ "$INSTALL_DEPS" == "true" ]; then
    SWIFT_VERSION=${SWIFT_VERSION} \
      sh ${PROJECT_DIRECTORY}/.evergreen/install-dependencies.sh
fi

# configure Swift
. ${PROJECT_DIRECTORY}/.evergreen/configure-swift.sh

SANITIZE_STATEMENT=""
if [ "$SANITIZE" != "false" ]; then
    SANITIZE_STATEMENT="--sanitize ${SANITIZE}"
fi

# build the driver
swift build $SANITIZE_STATEMENT

# test the driver
set +o errexit # even if tests fail we want to parse the results, so disable errexit
set -o pipefail # propagate error codes in the following pipes

# construct an optional filter statement for tests
FILTER_STATEMENT=""
if [ "$TEST_FILTER" != "NO_FILTER" ]; then
    FILTER_STATEMENT="--filter ${TEST_FILTER}"
fi

MONGODB_TOPOLOGY=${TOPOLOGY} MONGODB_URI=$MONGODB_URI SINGLE_MONGOS_LB_URI=$SINGLE_MONGOS_LB_URI \
MULTI_MONGOS_LB_URI=$MULTI_MONGOS_LB_URI MONGODB_API_VERSION=$MONGODB_API_VERSION \
swift test $FILTER_STATEMENT $SANITIZE_STATEMENT 2>&1 | tee ${RAW_TEST_RESULTS}

# save tests exit code
EXIT_CODE=$?

# convert tests to XML
cat ${RAW_TEST_RESULTS} | swift "${PROJECT_DIRECTORY}/etc/convert-test-results.swift" > ${XML_TEST_RESULTS}

# exit with exit code for running the tests
exit $EXIT_CODE
