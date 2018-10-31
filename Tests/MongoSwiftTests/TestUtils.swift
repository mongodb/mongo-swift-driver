import Foundation
import MongoSwift
import Nimble
import XCTest

extension XCTestCase {
    /// Gets the path of the directory containing spec files, depending on whether
    /// we're running from XCode or the command line
    func getSpecsPath() -> String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") { return "./Tests/Specs" }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: type(of: self)).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path
    }

    // indicates whether we are running on a 32-bit platform
    // Use MemoryLayout instead of Int.bitWidth to avoid a compiler warning.
    // See: https://forums.swift.org/t/how-can-i-condition-on-the-size-of-int/9080/4 */
    static let is32Bit = MemoryLayout<Int>.size == 4
}

extension MongoClient {
    internal func serverVersion() throws -> ServerVersion {
        let buildInfo = try self.db("admin").runCommand(["buildInfo": 1], options: RunCommandOptions(readPreference: ReadPreference(.primary)))
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

        static func == (lhs: ServerVersion, rhs: ServerVersion) -> Bool {
            return lhs.major == rhs.major &&
                    lhs.minor == rhs.minor &&
                    lhs.patch == rhs.patch
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

        if let min = min, version.isLessThan(try ServerVersion(min)) { return false }
        if let max = max, version.isGreaterThan(try ServerVersion(max)) { return false }

        return true
    }

    internal convenience init(options: ClientOptions? = nil) throws {
        try self.init(connectionString: getConnStr(), options: options)
    }
}

func getConnStr() -> String {
    if let connStr = ProcessInfo.processInfo.environment["MONGODB_URI"] {
        return connStr
    } else {
        return "mongodb://localhost:27017"
    }
}

/// Cleans and normalizes a given JSON string for comparison purposes
func clean(json: String?) -> String {
    guard let str = json else { return "" }
    do {
        // parse as [String: Any] so we get consistent key ordering
        guard let object = try JSONSerialization.jsonObject(with: str.data(using: .utf8)!, options: []) as? [String: Any] else {
            return String()
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            print("Unable to convert JSON data to Data: \(str)")
            return String()
        }
        return string
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
        case (let expected?, let actual?):
            let matches = bsonEquals(expected, actual)
            return PredicateResult(bool: matches, message: msg)
        }
    }
}
