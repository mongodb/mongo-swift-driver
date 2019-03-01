# Swift Driver Development Guide

## Index
* [Things to Install](#things-to-install) 
* [The Code](#the-code)
* [Building](#building)
* [Running Tests](#running-tests)
* [Writing and Generating Documentation](#writing-and-generating-documentation)
* [Linting and Style](#linting-and-style)
* [Workflow](#workflow)
* [Resources](#resources)

## Things to install
* [swiftenv](https://swiftenv.fuller.li/en/latest/installation.html): a command-line tool that allows easy installation of and switching between versions of Swift.
	* Use this to install Swift 4.2 if you don't have it already.
* [Jazzy](https://github.com/realm/jazzy#installation): the tool we use to generate documentation.
* [SwiftLint](https://github.com/realm/SwiftLint#using-homebrew): the Swift linter we use. 
* [Sourcery](https://github.com/krzysztofzablocki/Sourcery/#installation): the tool we use to generate lists of test names (required to run the tests on Linux).
* [libmongoc](http://mongoc.org/libmongoc/current/api.html): the MongoDB C driver, which this library wraps. See the installation instructions provided in our [README](https://mongodb.github.io/mongo-swift-driver/#first-install-the-mongodb-c-driver) or on the [libmongoc docs](http://mongoc.org/libmongoc/current/installing.html).

### If you are using (Vim/Neovim)
* [swift.vim](https://github.com/Utagai/swift.vim): A fork of Keith Smiley's `swift.vim` with fixed indenting rules. This adds proper indenting and syntax for Swift to Vim. This fork also provides a match rule for column width highlighting.
  * Please read the [NOTICE](https://github.com/Utagai/swift.vim#notice) for proper credits.

## The code
You should clone this repository, as well as the [MongoDB Driver specifications](https://github.com/mongodb/specifications). 
Since this library wraps the MongoDB C Driver, we also recommend cloning [mongodb/mongo-c-driver](https://github.com/mongodb/mongo-c-driver) so you have the source code and documentation easily accessible. 

## Building 
### From the Command line
Run `swift build` or simply `make` in the project's root directory. 

### In Xcode
We do not provide or maintain an already-generated `.xcodeproj` in our repository. Instead, you must generate it locally.

**To generate the `.xcodeproj` file**:
1. Install the Ruby gem `xcodeproj` with `gem install xcodeproj` (you may need to `sudo`)
2. Run `make project`
3. You're ready to go! Open `MongoSwift.xcodeproj` and build and test as normal.

Why is this necessary? The project requires a customized "copy resources" build phase to include various test `.json` files. By default, this phase is not included when you run `swift package generate-xcodeproj`. So `make project` first generates the project, and then uses `xcodeproj` to manually add the files to the appropriate targets (see `add_json_files.rb`). 

## Running Tests
**NOTE**: Several of the tests require a mongod instance to be running on the default host/port, `localhost:27017`.

You can run tests from Xcode as usual. If you prefer to test from the command line, keep reading.

### From the Command Line 
We recommend installing the ruby gem `xcpretty` and running tests by executing `make test-pretty`, as this provides output in a much more readable format. (Works on MacOS only.)

Alternatively, you can just run the tests with `swift test`, or `make test`.

To filter tests by regular expression:
- If you are using `swift test`, provide the `--filter` argument: for example, `swift test --filter=MongoClientTests`. 
- If you are using `make test` or `make test-pretty`, provide the `FILTER` environment variable: for example, `make test-pretty FILTER=MongoCollectionTests`. 

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

Our documentation site is automatically generated from the source code using [Jazzy](https://github.com/realm/jazzy#installation). We regenerate it each time we release a new version of the driver.
To regenerate the files, run `make documentation` from the project's root directory. You can then inspect the changes to the site by opening the files in `/docs` in your web browser.

## Linting and Style
We use [SwiftLint](https://github.com/realm/SwiftLint#using-homebrew) for linting. You can see our configuration in the `.swiftlint.yml` file in the project's root directory.  Run `swiftlint` in the `/Sources` directory to lint all of our files. Running `swiftlint autocorrect` will correct some types of violations.

For style guidance, look at Swift's [API design guidelines](https://swift.org/documentation/api-design-guidelines/) and Google's [Swift Style Guide](https://google.github.io/swift/).

### Sublime Text Setup
If you use Sublime Text, you can get linting violations shown in the editor by installing the packages [SublimeLinter](https://packagecontrol.io/packages/SublimeLinter) and [SublimeLinter-contrib-swiftlint](https://packagecontrol.io/packages/SublimeLinter-contrib-swiftlint). 

### Vim/Neovim Setup
If you use Vim or Neovim, then you can get linting support by using [`ale`](https://github.com/w0rp/ale) by `w0rp`. This will show symbols in the gutter for warnings/errors and show linter messages in the status.

## Workflow
1. Create a feature branch, named by the corresponding JIRA ticket if exists; for example, `SWIFT-30`. 
2. Do your work on the branch.
3. If you add, remove, or rename any tests, make sure to update `LinuxMain.swift` accordingly. If you are on MacOS, you can do that by running `make sourcery`. 
4. Make sure your code builds and passes all tests on [Travis](https://travis-ci.org/mongodb/mongo-swift-driver). Every time you push to GitHub or open a pull request, it will trigger a new build.
5. Open a pull request on the repository. Make sure you have rebased your branch onto the latest commits on `master`.

**Note**: GitHub allows marking comment threads on pull requests as "resolved", which hides them from view. Always allow the original commenter to resolve a conversation. This allows them to verify that your changes match what they requested before the conversation is hidden.

Once you get the required approvals and your code passes all tests:

6. Rebase on master again if needed.
7. Build and rerun tests. 
8. Squash all commits into a single, descriptive commit method, formatted as: `TICKET-NUMBER: Description of changes`. For example, `SWIFT-30: Implement WriteConcern type`. 
9. Merge it, or if you don't have permissions, ask someone to merge it for you.

If your change involves a libmongoc version bump, be sure to delete the master branch cache on Travis before merging (Navigate to "More Options > Caches").

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
