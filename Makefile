# CFLAGS = -Xcc -DMONGOC_COMPILATION -Xcc -DBSON_COMPILATION -Xcc -ISources/libbson -Xcc -ISources/libbson/include -Xcc -ISources/libbson/generated -Xcc -ISources/libmongoc/generated
# LDFLAGS = -Xlinker -lsasl2 -Xlinker -lz
CFLAGS =
LDFLAGS =

# If FILTER is not provided, a default filter of `MongoSwiftTests` will be used.
# Else, any test matching the filter in *either target* (MongoSwiftTests or MongoSwiftBenchmarks) will run.
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG = --filter MongoSwiftTests
endif

all:
	swift package generate-xcodeproj
	swift build -v $(CFLAGS) $(LDFLAGS)

test:
	swift test -v $(CFLAGS) $(LDFLAGS) $(FILTERARG)

benchmark:
	swift test -v $(CFLAGS) $(LDFLAGS) --filter MongoSwiftBenchmarks

lint:
	swiftlint

format:
	swiftformat --disable trailingCommas  --indent 2 .

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf MongoSwift.xcodeproj
	rm Package.resolved
