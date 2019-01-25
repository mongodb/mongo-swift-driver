# if provided, FILTER is used as the --filter argument to `swift test`. 
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG =
endif

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
	ruby Tests/Scripts/add_json_files.rb

test:
	swift test -v $(FILTERARG)

test-pretty:
	@$(call check_for_gem,xcpretty)
	set -o pipefail && swift test $(FILTERARG) 2>&1 | xcpretty

lint:
	swiftlint autocorrect
	swiftlint

coverage:
	make project
	xcodebuild -project MongoSwift.xcodeproj -scheme MongoSwift-Package -enableCodeCoverage YES build test

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf MongoSwift.xcodeproj
	rm Package.resolved

documentation:
	make project
	@$(call check_for_gem,jazzy)
	jazzy --module MongoSwift --module-version 0.0.9 --root-url https://mongodb.github.io/mongo-swift-driver/ --documentation Development.md
