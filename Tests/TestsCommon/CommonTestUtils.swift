import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

// sourcery: disableTests
open class MongoSwiftTestCase: XCTestCase {
    /// Gets the name of the database the test case is running against.
    public class var testDatabase: String {
        return "test"
    }

    /// Gets the connection string for the database being used for testing from the environment variable, $MONGODB_URI.
    /// If the environment variable does not exist, this will use a default of "mongodb://127.0.0.1/".
    public static var connStr: String {
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
    public static let is32Bit = MemoryLayout<Int>.size == 4

    /// Generates a unique collection name of the format "<Test Suite>_<Test Name>_<suffix>". If no suffix is provided,
    /// the last underscore is omitted.
    public func getCollectionName(suffix: String? = nil) -> String {
        var name = self.name.replacingOccurrences(of: "[\\[\\]-]", with: "", options: [.regularExpression])
        if let suf = suffix {
            name += "_" + suf
        }
        return name.replacingOccurrences(of: "[ \\+\\$]", with: "_", options: [.regularExpression])
    }

    public func getNamespace(suffix: String? = nil) -> MongoNamespace {
        return MongoNamespace(db: type(of: self).testDatabase, collection: self.getCollectionName(suffix: suffix))
    }

    public static var topologyType: TopologyDescription.TopologyType {
        guard let topology = ProcessInfo.processInfo.environment["MONGODB_TOPOLOGY"] else {
            return .single
        }
        return TopologyDescription.TopologyType(from: topology)
    }

    /// Indicates that we are running the tests with SSL enabled, determined by the environment variable $SSL.
    public static var ssl: Bool {
        return ProcessInfo.processInfo.environment["SSL"] == "ssl"
    }

    /// Returns the path where the SSL key file is located, determined by the environment variable $SSL_KEY_FILE.
    public static var sslPEMKeyFilePath: String? {
        return ProcessInfo.processInfo.environment["SSL_KEY_FILE"]
    }

    /// Returns the path where the SSL CA file is located, determined by the environment variable $SSL_CA_FILE..
    public static var sslCAFilePath: String? {
        return ProcessInfo.processInfo.environment["SSL_CA_FILE"]
    }

    /// Temporary helper to assist with skipping tests due to CDRIVER-3318. Returns whether we are running on MacOS.
    /// Remove when SWIFT-539 is completed.
    public static var isMacOS: Bool {
#if os(OSX)
        return true
#else
        return false
#endif
    }
}

extension Document {
    public func sortedEquals(_ other: Document) -> Bool {
        let keys = self.keys.sorted()
        let otherKeys = other.keys.sorted()

        // first compare keys, because rearrangeDoc will discard any that don't exist in `expected`
        expect(keys).to(equal(otherKeys))

        let rearranged = rearrangeDoc(other, toLookLike: self)
        return self == rearranged
    }
}

/// Cleans and normalizes a given JSON string for comparison purposes
private func clean(json: String?) -> String {
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
public func cleanEqual(_ expectedValue: String?) -> Predicate<String> {
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
public func sortedEqual(_ expectedValue: Document?) -> Predicate<Document> {
    return Predicate.define("sortedEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()

        guard let expected = expectedValue, let actual = actualValue else {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }

        let matches = expected.sortedEquals(actual)
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

public func unsupportedTopologyMessage(
    testName: String,
    topology: TopologyDescription.TopologyType = MongoSwiftTestCase.topologyType
)
    -> String {
    return "Skipping \(testName) due to unsupported topology type \(topology)"
}

public func unsupportedServerVersionMessage(testName: String) -> String {
    return "Skipping \(testName) due to unsupported server version."
}
