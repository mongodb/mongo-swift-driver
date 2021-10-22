# if provided, FILTER is used as the --filter argument to `swift test`.
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG =
endif

ifdef DOCSVERSION
	DOCSARG = --module-version $(DOCSVERSION)
else
	DOCSARG =
endif

# if no value provided assume sourcery is in the user's PATH
SOURCERY ?= sourcery

define check_for_gem
	gem list $(1) -i > /dev/null || gem install $(1) || { echo "ERROR: Failed to locate or install the ruby gem $(1); please install yourself with 'gem install $(1)' (you may need to use sudo)"; exit 1; }
endef

all:
	swift build -v

# project generates the .xcodeproj, and then modifies it to add
# spec .JSON files to the project
project:
	swift package generate-xcodeproj
	@$(call check_for_gem,xcodeproj)
	ruby etc/add_json_files.rb

exports:
	$(SOURCERY) --sources Sources/MongoSwift/ --templates Sources/MongoSwiftSync/Exports.stencil --output Sources/MongoSwiftSync/Exports.swift

test:
	swift test -v $(FILTERARG)

test-pretty:
	@$(call check_for_gem,xcpretty)
	set -o pipefail && swift test $(FILTERARG) 2>&1 | xcpretty

lint:
	swiftlint autocorrect
	swiftlint

# MacOS only
coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov export -format="lcov" .build/debug/mongo-swift-driverPackageTests.xctest/Contents/MacOS/mongo-swift-driverPackageTests -instr-profile .build/debug/codecov/default.profdata > info.lcov

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf MongoSwift.xcodeproj
	rm Package.resolved

