#!/bin/bash

# Script for installing various dependencies for Travis jobs.
# Usage: ./travis_install.sh mongodb|sourcery|swiftlint|swiftformat

# usage: install_from_gh [name] [url]
install_from_gh () {
	NAME=$1
	URL=$2
	mkdir ${PWD}/${NAME}
	curl -L ${URL} -o ${PWD}/${NAME}/${NAME}.zip
	unzip ${PWD}/${NAME}/${NAME}.zip -d ${PWD}/${NAME}
}

if [[ $1 == "mongodb" ]]
then
	MONGODB_BASE="mongodb-linux-x86_64"
	if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then MONGODB_BASE="mongodb-osx-ssl-x86_64"; fi

	# install mongodb
	wget http://fastdl.mongodb.org/${TRAVIS_OS_NAME}/${MONGODB_BASE}-${MONGODB_VERSION}.tgz
	mkdir mongodb-${MONGODB_VERSION}
	tar xzvf ${MONGODB_BASE}-${MONGODB_VERSION}.tgz -C mongodb-${MONGODB_VERSION} --strip-components 1
	${PWD}/mongodb-${MONGODB_VERSION}/bin/mongod --version

elif [[ $1 = "sourcery" ]]
then
	install_from_gh sourcery https://github.com/krzysztofzablocki/Sourcery/releases/download/1.0.0/Sourcery-1.0.0.zip

elif [[ $1 = "swiftlint" ]]
then
	install_from_gh swiftlint https://github.com/realm/SwiftLint/releases/download/0.41.0/portable_swiftlint.zip

elif [[ $1 = "swiftformat" ]]
then
  git clone https://github.com/nicklockwood/SwiftFormat --branch="0.47.13"
  pushd SwiftFormat
  swift build -c release
  popd

else
	echo Missing/unknown install option: "$1"
	echo Usage: "./travis_install.sh mongodb|sourcery|swiftlint|swiftformat"
fi
