#!/bin/sh

TARBALL_URL=https://github.com/mongodb/mongo-c-driver/releases/download/1.8.2/mongo-c-driver-1.8.2.tar.gz
TARBALL_NAME=`basename $TARBALL_URL`
TARBALL_DIR=`basename -s .tar.gz $TARBALL_NAME`

PWD=`pwd`
BSONROOT=$PWD/../Sources/libbson
MONGOCROOT=$PWD/../Sources/libmongoc

echo "REMOVING any previously vendored libmongoc code"
rm -rf $BSONROOT/include
rm -rf $BSONROOT/jsonsl
find $BSONROOT -type f -maxdepth 1 -exec rm {} \;

rm -rf $MONGOCROOT/include
find $MONGOCROOT -type f -maxdepth 1 -exec rm {} \;

mkdir -p $BSONROOT/include
mkdir -p $MONGOCROOT/include

WORK_DIR=`mktemp -d`
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

echo "Downloading source tarball..."
curl -L# -o $WORK_DIR/$TARBALL_NAME $TARBALL_URL

echo "Unpacking source, and copying files"
pushd $WORK_DIR
tar -xzf $TARBALL_NAME

echo "Copying libbson"
cp -r $TARBALL_DIR/src/libbson/src/jsonsl $BSONROOT
# cp $TARBALL_DIR/src/libbson/src/bson/*.h $BSONROOT/include
# mv `find $BSONROOT/include -name "*.h" | grep "private"` $BSONROOT
# rm `find $BSONROOT/include -name "*.h" | grep "win32"`
cp $TARBALL_DIR/src/libbson/src/bson/*.h $BSONROOT
mv $BSONROOT/bson.h $BSONROOT/include
cp $TARBALL_DIR/src/libbson/src/bson/*.c $BSONROOT
rm $BSONROOT/bson-version.h
rm $BSONROOT/bson-stdint.h

echo "Copying libmongoc"
cp $TARBALL_DIR/src/mongoc/*.h $MONGOCROOT/include
mv `find $MONGOCROOT/include -name "*.h" | grep "private"` $MONGOCROOT
cp $TARBALL_DIR/src/mongoc/*.c $MONGOCROOT
cp $TARBALL_DIR/src/mongoc/*.def $MONGOCROOT
cp $TARBALL_DIR/src/mongoc/*.defs $MONGOCROOT
