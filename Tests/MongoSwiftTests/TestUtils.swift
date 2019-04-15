import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

// sourcery: disableTests
class MongoSwiftTestCase: XCTestCase {
    /* Ensure libmongoc is initialized. This will be called multiple times, but that's ok
     * as repeated calls have no effect. There is no way to call final cleanup code just
     * once at the very end, either explicitly or with a deinit. This may appear as a
     * memory leak. */
    override class func setUp() {
        MongoSwift.initialize()
    }

    /// Gets the name of the database the test case is running against.
    internal class var testDatabase: String {
        return "test"
    }

    /// Gets the path of the directory containing spec files, depending on whether
    /// we're running from XCode or the command line
    static var specsPath: String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") {
            return "./Tests/Specs"
        }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: self).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path
    }

    /// Gets the connection string for the database being used for testing from the environment variable, $MONGODB_URI.
    /// If the environment variable does not exist, this will use a default of "mongodb://127.0.0.1/".
    static var connStr: String {
        if let connStr = ProcessInfo.processInfo.environment["MONGODB_URI"] {
            if self.topologyType == .sharded {
                guard let uri = mongoc_uri_new(connStr) else {
                    return connStr
                }

                defer {
                    mongoc_uri_destroy(uri)
                }

                guard let hosts = mongoc_uri_get_hosts(uri) else {
                    return connStr
                }

                let hostAndPort = withUnsafeBytes(of: hosts.pointee.host_and_port) { rawPtr -> String in
                    let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
                    return String(cString: ptr)
                }

                return "mongodb://\(hostAndPort)/"
            }

            return connStr
        }

        return "mongodb://127.0.0.1/"
    }

    // indicates whether we are running on a 32-bit platform
    static let is32Bit = Int.bsonType == .int32

    /// Generates a unique collection name of the format "<Test Suite>_<Test Name>_<suffix>". If no suffix is provided,
    /// the last underscore is omitted.
    internal func getCollectionName(suffix: String? = nil) -> String {
        var name = self.name.replacingOccurrences(of: "[\\[\\]-]", with: "", options: [.regularExpression])
        if let suf = suffix {
            name += "_" + suf
        }
        return name.replacingOccurrences(of: "[ \\+\\$]", with: "_", options: [.regularExpression])
    }

    static var topologyType: TopologyDescription.TopologyType {
        guard let topology = ProcessInfo.processInfo.environment["MONGODB_TOPOLOGY"] else {
            return .single
        }

        switch topology {
        case "sharded_cluster":
            return .sharded
        case "replica_set":
            return .replicaSetWithPrimary
        default:
            return .single
        }
    }
}

extension MongoClient {
    internal func serverVersion() throws -> ServerVersion {
        let buildInfo = try self.db("admin").runCommand(["buildInfo": 1],
                                                        options: RunCommandOptions(
                                                            readPreference: ReadPreference(.primary)
                                                        ))
        guard let versionString = buildInfo["version"] as? String else {
            throw TestError(message: "buildInfo reply missing version string: \(buildInfo)")
        }
        return try ServerVersion(versionString)
    }

    /// A struct representing a server version.
    internal struct ServerVersion: Equatable {
        let major: Int
        let minor: Int
        let patch: Int

        /// initialize a server version from a string
        init(_ str: String) throws {
            let versionComponents = str.split(separator: ".").prefix(3)
            guard versionComponents.count >= 2 else {
                throw TestError(message: "Expected version string \(str) to have at least two .-separated components")
            }

            guard let major = Int(versionComponents[0]) else {
                throw TestError(message: "Error parsing major version from \(str)")
            }
            guard let minor = Int(versionComponents[1]) else {
                throw TestError(message: "Error parsing minor version from \(str)")
            }

            var patch = 0
            if versionComponents.count == 3 {
                // in case there is text at the end, for ex "3.6.0-rc1", stop first time
                /// we encounter a non-numeric character.
                let numbersOnly = versionComponents[2].prefix { "0123456789".contains($0) }
                guard let patchValue = Int(numbersOnly) else {
                    throw TestError(message: "Error parsing patch version from \(str)")
                }
                patch = patchValue
            }

            self.init(major: major, minor: minor, patch: patch)
        }

        // initialize given major, minor, and optional patch
        init(major: Int, minor: Int, patch: Int? = nil) {
            self.major = major
            self.minor = minor
            self.patch = patch ?? 0
        }

        func isLessThan(_ version: ServerVersion) -> Bool {
            if self.major == version.major {
                if self.minor == version.minor {
                    // if major & minor equal, just compare patches
                    return self.patch < version.patch
                }
                // major equal but minor isn't, so compare minor
                return self.minor < version.minor
            }
            // just compare major versions
            return self.major < version.major
        }

        func isLessThanOrEqualTo(_ version: ServerVersion) -> Bool {
            return self == version || self.isLessThan(version)
        }

        func isGreaterThan(_ version: ServerVersion) -> Bool {
            return !self.isLessThanOrEqualTo(version)
        }

        func isGreaterThanOrEqualTo(_ version: ServerVersion) -> Bool {
            return !self.isLessThan(version)
        }
    }

    internal func serverVersionIsInRange(_ min: String?, _ max: String?) throws -> Bool {
        let version = try self.serverVersion()

        if let min = min, version.isLessThan(try ServerVersion(min)) {
            return false
        }
        if let max = max, version.isGreaterThan(try ServerVersion(max)) {
            return false
        }

        return true
    }

    internal convenience init(options: ClientOptions? = nil) throws {
        try self.init(MongoSwiftTestCase.connStr, options: options)
    }
}

/// Cleans and normalizes a given JSON string for comparison purposes
func clean(json: String?) -> String {
    guard let str = json else {
        return ""
    }
    do {
        let doc = try Document(fromJSON: str.data(using: .utf8)!)
        return doc.extendedJSON
    } catch {
        print("Failed to clean string: \(str)")
        return String()
    }
}

// Adds a custom "cleanEqual" predicate that compares two JSON strings for equality after normalizing
// them with the "clean" function
internal func cleanEqual(_ expectedValue: String?) -> Predicate<String> {
    return Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        let matches = clean(json: actualValue) == clean(json: expectedValue) && expectedValue != nil
        if expectedValue == nil || actualValue == nil {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

// Adds a custom "sortedEqual" predicate that compares two `Document`s and returns true if they
// have the same key/value pairs in them
internal func sortedEqual(_ expectedValue: Document?) -> Predicate<Document> {
    return Predicate.define("sortedEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()

        if expectedValue == nil || actualValue == nil {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }

        let expectedKeys = expectedValue?.keys.sorted()
        let actualKeys = actualValue?.keys.sorted()

        // first compare keys, because rearrangeDoc will discard any that don't exist in `expected`
        expect(expectedKeys).to(equal(actualKeys))

        let rearranged = rearrangeDoc(actualValue!, toLookLike: expectedValue!)
        let matches = expectedValue == rearranged
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

/// Given two documents, returns a copy of the input document with all keys that *don't*
/// exist in `standard` removed, and with all matching keys put in the same order they
/// appear in `standard`.
internal func rearrangeDoc(_ input: Document, toLookLike standard: Document) -> Document {
    var output = Document()
    for (k, v) in standard {
        // if it's a document, recursively rearrange to look like corresponding sub-document
        if let sDoc = v as? Document, let iDoc = input[k] as? Document {
            output[k] = rearrangeDoc(iDoc, toLookLike: sDoc)

        // if it's an array, recursively rearrange to look like corresponding sub-array
        } else if let sArr = v as? [Document], let iArr = input[k] as? [Document] {
            var newArr = [Document]()
            for (i, el) in iArr.enumerated() {
                newArr.append(rearrangeDoc(el, toLookLike: sArr[i]))
            }
            output[k] = newArr
        // just copy the value over as is
        } else {
            output[k] = input[k]
        }
    }
    return output
}

/// A Nimble matcher for testing BSONValue equality.
internal func bsonEqual(_ expectedValue: BSONValue?) -> Predicate<BSONValue> {
    return Predicate.define("equal <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        switch (expectedValue, actualValue) {
        case (nil, _?):
            return PredicateResult(status: .fail, message: msg.appendedBeNilHint())
        case (nil, nil), (_, nil):
            return PredicateResult(status: .fail, message: msg)
        case let (expected?, actual?):
            let matches = expected.bsonEquals(actual)
            return PredicateResult(bool: matches, message: msg)
        }
    }
}
