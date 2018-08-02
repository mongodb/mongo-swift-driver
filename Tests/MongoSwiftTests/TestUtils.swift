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
}

extension MongoClient {
    internal func serverVersion() throws -> String {
        let buildInfo = try self.db("admin").runCommand(["buildInfo": 1])
        guard let versionString = buildInfo["version"] as? String else {
            throw TestError(message: "buildInfo reply missing version string: \(buildInfo)")
        }
        return versionString
    }

    internal func serverVersionIsInRange(_ min: String?, _ max: String?) throws -> Bool {
        let version = try self.serverVersion()
        if let min = min, min > version { return false }
        if let max = max, max < version { return false }
        return true
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
