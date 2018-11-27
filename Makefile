# If FILTER is not provided, a default filter of `MongoSwiftTests` will be used.
# Else, any test matching the filter in *either target* (MongoSwiftTests or MongoSwiftBenchmarks) will run.
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG =
endif

all:
	swift build -v

project:
	swift package generate-xcodeproj
	@# use xcodeproj to add .json files to the project
	@gem list xcodeproj -i > /dev/null || gem install xcodeproj || { echo "ERROR: Failed to locate or install the ruby gem xcodeproj; please install yourself with 'gem install xcodeproj' (you may need to use sudo)"; exit 1; }
	ruby add_json_files.rb

test:
	swift test -v $(FILTERARG)

lint:
	swiftlint autocorrect
	swiftlint

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf MongoSwift.xcodeproj
	rm Package.resolved

documentation:
	make project
	@gem list jazzy -i > /dev/null || gem install jazzy || { echo "ERROR: Failed to locate or install the ruby gem jazzy; please install yourself with 'gem install jazzy' (you may need to use sudo)"; exit 1; }
	jazzy --module MongoSwift --module-version 0.0.7 --root-url https://mongodb.github.io/mongo-swift-driver/ --documentation Development.md
