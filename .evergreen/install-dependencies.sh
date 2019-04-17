#!/bin/sh
set -o xtrace   # Write all commands first to stderr
set -o errexit  # Exit the script with error if any of the commands fail

# variables
PROJECT_DIRECTORY=${PROJECT_DIRECTORY:-$PWD}
SWIFT_VERSION=${SWIFT_VERSION:-4.2}
INSTALL_DIR="${PROJECT_DIRECTORY}/opt"
BUILD_DIR="${PROJECT_DIRECTORY}/libmongoc-build"
EVG_DIR=$(dirname $0)

export SWIFTENV_ROOT="${INSTALL_DIR}/swiftenv"
export PATH=/opt/cmake/bin:${SWIFTENV_ROOT}/bin:$PATH

# should be set by EVG eventuallty
LIBMONGOC_VERSION="r1.13"

# find cmake and set the path to it in $CMAKE
. $EVG_DIR/find-cmake.sh

# install libmongoc
git clone --depth 1 -b "${LIBMONGOC_VERSION}" https://github.com/mongodb/mongo-c-driver "${BUILD_DIR}"
cd "${BUILD_DIR}"
$CMAKE -DCMAKE_INSTALL_PREFIX:PATH="${INSTALL_DIR}"
make -j8 install
cd "${PROJECT_DIRECTORY}"

# install swiftenv
git clone --depth 1 https://github.com/kylef/swiftenv.git "${SWIFTENV_ROOT}"

# install swift

eval "$(swiftenv init -)"
swiftenv install $SWIFT_VERSION
