#!/bin/bash -x

set -eou pipefail

PWD=`pwd`
LIBMONGOC_MAJOR_VERSION=1
LIBMONGOC_MINOR_VERSION=19
LIBMONGOC_PATCH_VERSION=0
LIBMONGOC_PRERELEASE_VERSION=

LIBMONGOC_FULL_VERSION=${LIBMONGOC_MAJOR_VERSION}.${LIBMONGOC_MINOR_VERSION}.${LIBMONGOC_PATCH_VERSION}${LIBMONGOC_PRERELEASE_VERSION:+-$LIBMONGOC_PRERELEASE_VERSION}

TARBALL_URL=https://github.com/mongodb/mongo-c-driver/releases/download/$LIBMONGOC_FULL_VERSION/mongo-c-driver-$LIBMONGOC_FULL_VERSION.tar.gz
TARBALL_NAME=`basename $TARBALL_URL`
TARBALL_DIR=`basename -s .tar.gz $TARBALL_NAME`

# install paths
CLIBMONGOC_PATH=$PWD/Sources/CLibMongoC
CLIBMONGOC_INCLUDE_PATH=$CLIBMONGOC_PATH/include
COMMON_PATH=$CLIBMONGOC_PATH/common
BSON_PATH=$CLIBMONGOC_PATH/bson
MONGOC_PATH=$CLIBMONGOC_PATH/mongoc

# source paths
ETC_DIR=$PWD/etc
COMMON_SRC_PATH=$TARBALL_DIR/src/common
BSON_SRC_PATH=$TARBALL_DIR/src/libbson/src/bson
JSONSL_SRC_PATH=$TARBALL_DIR/src/libbson/src/jsonsl
MONGOC_SRC_PATH=$TARBALL_DIR/src/libmongoc/src/mongoc

WORK_DIR=`mktemp -d`
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

sed="$ETC_DIR/sed.sh"

echo "REMOVING any previously vendored libmongoc code"
rm -rf $CLIBMONGOC_INCLUDE_PATH
rm -rf $COMMON_PATH
rm -rf $BSON_PATH
rm -rf $MONGOC_PATH

mkdir -p $CLIBMONGOC_INCLUDE_PATH
mkdir -p $COMMON_PATH
mkdir -p $BSON_PATH
mkdir -p $MONGOC_PATH

echo "DOWNLOADING source tarball..."
curl -L# -o $WORK_DIR/$TARBALL_NAME $TARBALL_URL

# This step copies all files from the tarball into `Sources/CLibMongoC`. It takes an extra step
# to maintain private headers in component-specific folders (`bson`, `mongoc`, `common`), and
# otherwise copy headers into the common clang-module expected `include` folder
echo "COPYING libmongoc"
(
  pushd $WORK_DIR
  tar -xzf $TARBALL_NAME

  # common
  cp $COMMON_SRC_PATH/*.h $CLIBMONGOC_INCLUDE_PATH
  cp $COMMON_SRC_PATH/*.c $COMMON_PATH

  # bson
  cp $BSON_SRC_PATH/*.h $BSON_PATH
  find $BSON_PATH -type f -not -name "*-private.h" -exec mv '{}' $CLIBMONGOC_INCLUDE_PATH \;
  cp $BSON_SRC_PATH/*.c $BSON_PATH
  cp $JSONSL_SRC_PATH/*.h $BSON_PATH
  cp $JSONSL_SRC_PATH/*.c $BSON_PATH

  # mongoc
  cp $MONGOC_SRC_PATH/*.h $MONGOC_PATH
  find $MONGOC_PATH -type f -not -name "*-private.h" -and -not -name "utlist.h" -exec mv '{}' $CLIBMONGOC_INCLUDE_PATH \;
  cp $MONGOC_SRC_PATH/*.def $CLIBMONGOC_INCLUDE_PATH
  cp $MONGOC_SRC_PATH/*.defs $CLIBMONGOC_INCLUDE_PATH
  cp $MONGOC_SRC_PATH/*.c $MONGOC_PATH
  popd
)

# These files are usually generated as part of a cmake run. Since we are building with
# SwiftPM we don't have the benefit of being able to generate them, so we'll copy in
# handcrafted versions of the file. Since we know a lot about the architecture from
# SwiftPM, we are able to inject our own defines and switch on that behavior from within
# the config files
echo "COPYING generated files"
cp $ETC_DIR/generated_headers/* $CLIBMONGOC_INCLUDE_PATH

# Embed libmongoc version info in generated headers
echo "PATCHING header files to include libmongoc version info"
(
  find $CLIBMONGOC_INCLUDE_PATH -name "*.h" | \
    xargs $sed -i -e "s+__LIBMONGOC_MAJOR_VERSION__+${LIBMONGOC_MAJOR_VERSION}+" \
                  -e "s+__LIBMONGOC_MINOR_VERSION__+${LIBMONGOC_MINOR_VERSION}+" \
                  -e "s+__LIBMONGOC_PATCH_VERSION__+${LIBMONGOC_PATCH_VERSION}+" \
                  -e "s+__LIBMONGOC_PRERELEASE_VERSION__+${LIBMONGOC_PRERELEASE_VERSION}+" \
                  -e "s+__LIBMONGOC_FULL_VERSION__+${LIBMONGOC_FULL_VERSION}+" \
)

# This is perhaps the most complicated step of the vendoring process. In the previous step
# we are building a single, monolithic version of `libmongoc` and `libbson` in our `CLibMongoC`
# module, which requires moving headers around so that they can be exported properly and
# accessible to all the source files compiled. The following lines do the work of rewriting
# these locations in the source itself. There are a few extra goodies below the main sed
# command which are mostly inconsistencies with naming or file location within the libmongoc
# codebase itself
echo "RENAMING header files"
(
  # NOTE: the below sed syntax uses addresses to include or ingore lines including the word `private`
  find $CLIBMONGOC_PATH -name "*.[ch]" | \
    xargs $sed -i -e 's+include "common+include "CLibMongoC_common+' \
                  -e 's+include <common-thread-private.h>+include "CLibMongoC_common-thread-private.h"+' \
                  \
                  -e '/private/! s+include "bson.h"+include "CLibMongoC_bson.h"+' \
                  -e '/private/! s+include "bcon.h"+include "CLibMongoC_bcon.h"+' \
                  -e '/private/! s+include "bson-+include "CLibMongoC_bson-+' \
                  -e '/private/! s+include <bson-+include <CLibMongoC_bson-+' \
                  -e '/private/! s+include "bson/+include "CLibMongoC_+' \
                  -e '/private/! s+include <bson/+include <CLibMongoC_+' \
                  -e '/private/ s+include "bson/+include "+' \
                  \
                  -e '/private/! s+include "mongoc.h"+include "CLibMongoC_mongoc.h"+' \
                  -e '/private\|defs/! s+include "mongoc-+include "CLibMongoC_mongoc-+' \
                  -e '/private/! s+include "mongoc/+include "CLibMongoC_+' \
                  -e '/private/! s+include <mongoc-+include <CLibMongoC_mongoc-+' \
                  -e '/private/ s+include "mongoc/+include "+' \
                  \
                  -e 's+CLibMongoC_utlist.h+utlist.h+' \
                  -e 's+PRId64+\"lld\"+'

  # fix jsonsl references
  $sed -i -e 's+include "jsonsl/+include "+' $BSON_PATH/bson-json.c
  $sed -i -e 's+include "../bson/+include "CLibMongoC_+' $BSON_PATH/jsonsl.h

  # fix one-off oddities
  $sed -i -e 's+include "bson-types+include "CLibMongoC_bson-types+' $BSON_PATH/bson-iter.c
  $sed -i -e '/private/! s+include "mongoc-+include "CLibMongoC_mongoc-+' $MONGOC_PATH/mongoc-stream-gridfs-download-private.h
  $sed -i -e '/private/! s+include "mongoc-+include "CLibMongoC_mongoc-+' $MONGOC_PATH/mongoc-stream-gridfs-upload-private.h

  # fix prelude define requirements, to work around xcode not supporting defines passed via SwiftPM
  $sed -i -e 's+#error+// #error+' $CLIBMONGOC_INCLUDE_PATH/mongoc-prelude.h
  $sed -i -e 's+#error+// #error+' $CLIBMONGOC_INCLUDE_PATH/bson-prelude.h
  $sed -i -e 's+#error+// #error+' $CLIBMONGOC_INCLUDE_PATH/common-prelude.h

  pushd $CLIBMONGOC_INCLUDE_PATH
  find . -name "*.h" | $sed -e "s_./__" | xargs -I {} mv {} CLibMongoC_{}
  find . -name "*.h" | xargs $sed -i -e 's/include "bson/include "CLibMongoC_/' -e 's/include <CLibMongoC_\(.*\)>/include "CLibMongoC_\1"/'
  find . -name "*.h" | xargs $sed -i -e 's+include "mongoc/+include "CLibMongoC_/+' -e 's/include <CLibMongoC_\(.*\)>/include "CLibMongoC_\1"/'
  popd
)

# Here we would apply any number of larger patches that don't fit into a single sed line.
echo "PATCHING libmongoc"
git apply ${ETC_DIR}/lower-minheartbeatfrequencyms.diff
git apply ${ETC_DIR}/inttypes-non-modular-header-workaround.diff
# TODO SWIFT-1319: Remove.
git apply ${ETC_DIR}/expose-mock-service-id.diff

# Clang modules are build by a conventional structure with an `include` folder for public
# includes, and an umbrella header used as the primary entry point. As part of the vendoring
# process, we copy in our own handwritten umbrella file. Currently, there is no generated
# data going into it, but we could conceivably do that here if needed
echo "COPYING umbrella header"
cp $ETC_DIR/CLibMongoC.h.in $CLIBMONGOC_INCLUDE_PATH/CLibMongoC.h

# cleanp the temporary work directory
rm -rf $WORK_DIR
