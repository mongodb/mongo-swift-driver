# ---------------------------------------------------------------------------
# Builder container
# ---------------------------------------------------------------------------

# You can set the Swift version to what you need for your app.
# Versions can be found here: https://hub.docker.com/_/swift
FROM swift:4.2 as builder

# For local build, add `--build-arg env=docker`
# In your application, you can use `Environment.custom(name: "docker")` to check if you're in this env
# ARG env

RUN apt-get -qq update && apt-get -q -y install \
  tzdata \
  git cmake libssl-dev libsasl2-dev \
  && rm -r /var/lib/apt/lists/*

# Compiling latest libmongoc and libbson
RUN git clone -b r1.13 https://github.com/mongodb/mongo-c-driver /tmp/libmongoc
WORKDIR /tmp/libmongoc
RUN cmake \
  -DCMAKE_INSTALL_PREFIX:PATH=/usr \
  -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF \
  -DCMAKE_BUILD_TYPE=Release
RUN make -j8 install

WORKDIR /app
COPY . .
RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so /build/lib
RUN swift build -c release && mv `swift build -c release --show-bin-path` /build/bin

# ---------------------------------------------------------------------------
# Production image
# ---------------------------------------------------------------------------

FROM ubuntu:16.04

RUN apt-get -qq update && apt-get install -y \
  libicu55 libxml2 libbsd0 libcurl3 libatomic1 \
  tzdata \
  git cmake libssl-dev libsasl2-dev \
  && rm -r /var/lib/apt/lists/*

# Compiling latest libmongoc and libbson
RUN git clone -b r1.13 https://github.com/mongodb/mongo-c-driver /tmp/libmongoc
WORKDIR /tmp/libmongoc
RUN cmake \
  -DCMAKE_INSTALL_PREFIX:PATH=/usr \
  -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF \
  -DCMAKE_BUILD_TYPE=Release
RUN make -j8 install

WORKDIR /app
COPY .env.development .env
COPY --from=builder /build/bin/Run .
COPY --from=builder /build/lib/* /usr/lib/

# Uncomment the next line if you need to load resources from the `Public` directory
#COPY --from=builder /app/Public ./Public
# Uncommand the next line if you are using Leaf
#COPY --from=builder /app/Resources ./Resources
# ENV ENVIRONMENT=$env

EXPOSE 8080
ENTRYPOINT ./Run serve --env production --hostname 0.0.0.0 --port 8080