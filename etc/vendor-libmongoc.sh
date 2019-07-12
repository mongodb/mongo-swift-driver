#!/bin/bash -x

set -eou pipefail

PWD=`pwd`
LIBMONGOC_VERSION=1.15.2
TARBALL_URL=https://github.com/mongodb/mongo-c-driver/releases/download/$LIBMONGOC_VERSION/mongo-c-driver-$LIBMONGOC_VERSION.tar.gz
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

case "$(uname -s)" in
    Darwin)
        sed=gsed
        ;;
    *)
        sed=sed
        ;;
esac

if ! hash ${sed} 2>/dev/null; then
    echo "You need sed \"${sed}\" to run this script ..."
    echo
    echo "On macOS: brew install gnu-sed"
    exit 43
fi

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

echo "COPYING libmongoc"
(
  pushd $WORK_DIR
  tar -xzf $TARBALL_NAME

  # common
  cp $COMMON_SRC_PATH/*.h $COMMON_PATH
  cp $COMMON_SRC_PATH/*.c $COMMON_PATH

  # bson
  cp $BSON_SRC_PATH/*.h $BSON_PATH
  find $BSON_PATH -type f -not -name "*-private.h" -exec mv -t $CLIBMONGOC_INCLUDE_PATH {} \;
  cp $BSON_SRC_PATH/*.c $BSON_PATH
  cp $JSONSL_SRC_PATH/*.h $BSON_PATH
  cp $JSONSL_SRC_PATH/*.c $BSON_PATH

  # mongoc
  cp $MONGOC_SRC_PATH/*.h $MONGOC_PATH
  find $MONGOC_PATH -type f -not -name "*-private.h" -and -not -name "utlist.h" -exec mv -t $CLIBMONGOC_INCLUDE_PATH {} \;
  cp $MONGOC_SRC_PATH/*.def $CLIBMONGOC_INCLUDE_PATH
  cp $MONGOC_SRC_PATH/*.defs $CLIBMONGOC_INCLUDE_PATH
  cp $MONGOC_SRC_PATH/*.c $MONGOC_PATH
  popd
)

echo "COPYING generated files"
cp $ETC_DIR/generated_headers/* $CLIBMONGOC_INCLUDE_PATH

echo "RENAMING header files"
(
  find $CLIBMONGOC_PATH -name "*.[ch]" | \
    xargs $sed -i -e '/private/! s+include "bson/+include "CLibMongoC_+' \
                  -e '/private/! s+include <bson/+include <CLibMongoC_+' \
                  -e '/private/ s+include "bson/+include "+' \
                  -e '/private/! s+include "mongoc/+include "CLibMongoC_+' \
                  -e '/private/! s+include <mongoc/+include <CLibMongoC_+' \
                  -e '/private/ s+include "mongoc/+include "+' \
                  -e 's+CLibMongoC_utlist.h+utlist.h+'

  # fix jsonsl references
  $sed -i -e 's+include "jsonsl/+include "+' $BSON_PATH/bson-json.c
  $sed -i -e 's+include "../bson/+include "CLibMongoC_+' $BSON_PATH/jsonsl.h

  # fix one-off oddities
  $sed -i -e 's+include "bson-types+include "CLibMongoC_bson-types+' $BSON_PATH/bson-iter.c
  $sed -i -e '/private/! s+include "mongoc-+include "CLibMongoC_mongoc-+' $MONGOC_PATH/mongoc-stream-gridfs-download-private.h
  $sed -i -e '/private/! s+include "mongoc-+include "CLibMongoC_mongoc-+' $MONGOC_PATH/mongoc-stream-gridfs-upload-private.h

  pushd $CLIBMONGOC_INCLUDE_PATH
  find . -name "*.h" | $sed -e "s_./__" | xargs -I {} mv {} CLibMongoC_{}
  find . -name "*.h" | xargs $sed -i -e 's/include "bson/include "CLibMongoC_/' -e 's/include <CLibMongoC_\(.*\)>/include "CLibMongoC_\1"/'
  find . -name "*.h" | xargs $sed -i -e 's+include "mongoc/+include "CLibMongoC_/+' -e 's/include <CLibMongoC_\(.*\)>/include "CLibMongoC_\1"/'
  popd
)

echo "COPYING umbrella header"
cp $ETC_DIR/CLibMongoC.h.in $CLIBMONGOC_INCLUDE_PATH/CLibMongoC.h

# cleanp the temporary work directory
rm -rf $WORK_DIR
