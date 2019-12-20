# Building `libmongoc` From Source With Docker

For the `mongo-swift-driver` to run, **the minimum required version of the
C Driver is 1.15.3**. The easiest way to get the correct version
of `libmongoc` and `libbson` is to checkout the correct
[branch](https://github.com/mongodb/mongo-c-driver/tree/r1.15) from git and
build the sources.

## Dependencies

* Ubuntu 16.04 / 18.04
* git
* cmake
* libssl-dev
* libsasl2-dev

## Build

```Dockerfile
RUN git clone -b r1.15 https://github.com/mongodb/mongo-c-driver /tmp/libmongoc
WORKDIR /tmp/libmongoc
RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr
RUN make -j8 install
```

Further useful `cmake` prefixes are:

- `-DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF` see [reference here](http://mongoc.org/libmongoc/current/init-cleanup.html).
- `-DCMAKE_BUILD_TYPE=Release` to build a release optimized build.

## Vapor

When building and running Vapor in Docker, the C Driver is needed in both the
builder and runner containers. See `Dockerfile.vapor` for an example.
