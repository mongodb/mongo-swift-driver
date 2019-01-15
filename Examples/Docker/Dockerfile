FROM ubuntu:16.04

# Getting the tools needed for building from source
RUN apt-get -qq update && apt-get install -y \
  git cmake libssl-dev libsasl2-dev \
  && rm -r /var/lib/apt/lists/*

# Compiling latest libmongoc and libbson
RUN git clone -b r1.13 https://github.com/mongodb/mongo-c-driver /tmp/libmongoc
WORKDIR /tmp/libmongoc
RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr
RUN make -j8 install

WORKDIR /app