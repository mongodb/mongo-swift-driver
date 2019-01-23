#!/bin/bash

# Script for installing various dependencies for Travis jobs.
# Usage: ./travis_install.sh libmongoc|mongodb|swiftlint

if [[ $1 == "libmongoc" ]]
then
	git clone -b r1.13 https://github.com/mongodb/mongo-c-driver /tmp/libmongoc
	pushd /tmp/libmongoc
	if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr/local; fi
	if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr; fi
	sudo make -j8 install
	popd

elif [[ $1 == "mongodb" ]]
then
	MONGODB_BASE="mongodb-linux-x86_64"
	if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then MONGODB_BASE="mongodb-osx-ssl-x86_64"; fi

	# install mongodb
	wget http://fastdl.mongodb.org/${TRAVIS_OS_NAME}/${MONGODB_BASE}-${MONGODB_VERSION}.tgz
	mkdir mongodb-${MONGODB_VERSION}
	tar xzvf ${MONGODB_BASE}-${MONGODB_VERSION}.tgz -C mongodb-${MONGODB_VERSION} --strip-components 1
	${PWD}/mongodb-${MONGODB_VERSION}/bin/mongod --version

elif [[ $1 = "swiftlint" ]]
then
	mkdir ${PWD}/swiftlint
	curl -L https://github.com/realm/SwiftLint/releases/download/0.29.3/portable_swiftlint.zip -o ${PWD}/swiftlint/swiftlint.zip
	unzip ${PWD}/swiftlint/swiftlint.zip -d ${PWD}/swiftlint

else
	echo Missing/unknown install option: "$1"
	echo Usage: "./travis_install.sh libmongoc|mongodb|swiftlint"
fi
