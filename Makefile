CFLAGS = -Xcc -DMONGOC_COMPILATION -Xcc -DBSON_COMPILATION -Xcc -ISources/libbson -Xcc -ISources/libbson/include -Xcc -ISources/libbson/generated -Xcc -ISources/libmongoc/generated
LDFLAGS = -Xlinker -lsasl2 -Xlinker -lz

ifdef FILTER
	FILTERARG = --filter $(FILTER)
endif

all:
	swift package generate-xcodeproj
	swift build -v $(CFLAGS) $(LDFLAGS)

test:
	swift test -v $(CFLAGS) $(LDFLAGS) $(FILTERARG)

lint:
	swiftlint

format:
	swiftformat --disable trailingCommas  --indent 2 .

clean:
	rm -rf Packages
	rm -rf .build
	rm -rf MongoSwift.xcodeproj
