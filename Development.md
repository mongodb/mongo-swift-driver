# Swift Driver Development Guide

## Index
* [Things to Install](#things-to-install) 
* [The Code](#the-code)
* [Building](#building)
* [Running Tests](#running-tests)
* [Writing and Generating Documentation](#writing-and-generating-documentation)
* [Linting](#linting)
* [Workflow](#workflow)
* [Resources](#resources)

## Things to install
* [swiftenv](https://swiftenv.fuller.li/en/latest/installation.html): a command-line tool that allows easy installation of and switching between versions of Swift.
	* Use this to install Swift 4.0 if you don't have it already.
* [jazzy](https://github.com/realm/jazzy#installation): the tool we use to generate documentation.
* [swiftlint](https://github.com/realm/SwiftLint#using-homebrew): the Swift linter we use. 
* [libmongoc](http://mongoc.org/libmongoc/current/api.html): the MongoDB C driver, which this library wraps. See the installation instructions provided in our [README](README.md#first-install-the-mongodb-c-driver) or on the [libmongoc docs](http://mongoc.org/libmongoc/current/installing.html). 

## The code
You should clone this repository, as well as the [MongoDB Driver specifications](https://github.com/mongodb/specifications). 
Since this library wraps the MongoDB C Driver, we also recommend cloning [mongodb/mongo-c-driver](https://github.com/mongodb/mongo-c-driver) so you have the source code and documentation easily accessible. 

## Building 
### From the Command line
Run `make` from the project's root directory. 

### In Xcode
We do not provide or maintain an already-generated `.xcodeproj` in our repository. Instead, you must generate it locally.

**To generate the `.xcodeproj` file**:
1. Install the Ruby gem `xcodeproj` with `gem install xcodeproj` (you may need to `sudo`)
2. Run `make project`
3. You're ready to go! Open `MongoSwift.xcodeproj` and build and test as normal.

Why is this necessary? The project requires a customized "copy resources" build phase to include various test `.json` files. By default, this phase is not included when you run `swift package generate-xcodeproj`. So `make project` first generates the project, and then uses `xcodeproj` to manually add the files to the appropriate targets (see `add_json_files.rb`). 

## Running Tests
**NOTE**: Several of the tests require a mongod instance to be running on the default host/port, `localhost:27017`.

Additionally, please note that each benchmark test runs for a minimum of 1 minute and therefore **the entire benchmark suite will take around 20-30 minutes to complete**.

You can run tests from Xcode as usual. If you prefer to test from the command line, keep reading.

### From the Command Line 
Tests can be run from the command line with `make test`. By default, this will run all the tests excluding the benchmarks.

To only run particular tests, use the `FILTER` environment variable, which is passed as the `filter` argument to `swift test`. This will run test cases with names matching a regular expression, formatted as follows: `<test-target>.<test-case>` or `<test-target>.<test-case>/<test>`.

For example, `make test FILTER=ClientTests` will run `MongoSwiftTests.ClientTests/*`. Or, `make test FILTER=testInsertOne` will only run `MongoSwiftTests.CollectionTests/testInsertOne`. 

To run all of the benchmarks, use `make benchmark` (equivalent to `FILTER=MongoSwiftBenchmarks`). To run a particular benchmark, use the `FILTER` environment variable to specify the name. To have the benchmark results all printed out at the end, run with `make benchmark | python Tests/MongoSwiftBenchmarks/benchmark.py`.

### Diagnosing Backtraces on Linux

[SWIFT-755](https://bugs.swift.org/browse/SR-755) documents an outstanding problem on Linux where backtraces do not contain debug symbols. As discussed in [this Stack Overflow thread](https://stackoverflow.com/a/44956167/162228), a [`symbolicate-linux-fatal`](https://github.com/apple/swift/blob/master/utils/symbolicate-linux-fatal) script may be used to add symbols to an existing backtrace. Consider the following:

```
$ swift test --filter CrashingTest &> crash.log
$ symbolicate-linux-fatal /path/to/MongoSwiftPackageTests.xctest crash.log
```

This will require you to manually provide the path to the compiled test binary (e.g. `.build/x86_64-unknown-linux/debug/MongoSwiftPackageTests.xctest`).

## Writing and Generating Documentation
We document new code as we write it. We use C-style documentation blocks (`/** ... */`) for documentation longer than 3 lines, and triple-slash (`///`) for shorter documentation. 
Comments that are _not_ documentation should use two slashes (`//`).

Our documentation site is automatically generated from the source code using [jazzy](https://github.com/realm/jazzy#installation). 
To regenerate the files after making changes, run `make documentation` from the project's root directory. You can then inspect the changes to the site by opening the files in `/docs` in your web browser.

## Linting
We use [swiftlint](https://github.com/realm/SwiftLint#using-homebrew) for linting. You can see our configuration in the `.swiftlint.yml` file in the project's root directory.  Run `swiftlint` in the `/Sources` directory to lint all of our files. Running `swiftlint autocorrect` will correct some types of violations.

### Sublime Text Setup
If you use Sublime Text, you can get linting violations shown in the editor by installing the packages [SublimeLinter](https://packagecontrol.io/packages/SublimeLinter) and [SublimeLinter-contrib-swiftlint](https://packagecontrol.io/packages/SublimeLinter-contrib-swiftlint). 

## Workflow
1. Create a feature branch, named by the corresponding JIRA ticket if exists; for example, `SWIFT-30`. 
2. Do your work on the branch.
3. Open a pull request on the repository. Make sure you have rebased your branch onto the latest commits on `master`. 

Once you get the required approvals and your code passes all tests:

4. Rebase on master again if needed.
5. Build and rerun tests. 
6. If your code includes any new documentation or changes to documentation, run `make documentation` and commit the resulting changes.
7. Squash all commits into a single, descriptive commit method, formatted as: `TICKET-NUMBER: Description of changes`. For example, `SWIFT-30: Implement WriteConcern type`. 
8. Merge it, or if you don't have permissions, ask someone to merge it for you.

## Resources

### Swift
* [Swift Language Guide](https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html)
* [Swift Standard Library docs](https://developer.apple.com/documentation/swift)

### MongoDB and Drivers
* [MongoSwift docs](https://mongodb.github.io/mongo-swift-driver/)
* [libmongoc docs](http://mongoc.org/libmongoc/current/index.html)
* [libbson docs](http://mongoc.org/libbson/current/index.html)
* [MongoDB docs](https://docs.mongodb.com/)
* [Driver specifications](https://github.com/mongodb/specifications)
