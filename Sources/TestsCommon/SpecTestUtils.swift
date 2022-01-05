import Foundation
@testable import MongoSwift
import NIO
import XCTest

extension MongoSwiftTestCase {
    /// Gets the path of the directory containing spec files.
    static var specsPath: String {
        // Approach taken from https://stackoverflow.com/a/58034307
        // TODO: SWIFT-1442 Once we drop Swift < 5.3 we can switch to including the JSON files as Resources via our
        // package manifest instead.
        let thisFile = URL(fileURLWithPath: #file)
        let baseDirectory = thisFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return baseDirectory.appendingPathComponent("Tests").appendingPathComponent("Specs").path
    }
}

/// Given a spec folder name (e.g. "crud") and optionally a subdirectory name for a folder (e.g. "read") retrieves an
/// array of [(filename, file decoded to type T)].
public func retrieveSpecTestFiles<T: Decodable>(
    specName: String,
    subdirectory: String? = nil,
    excludeFiles: [String] = [],
    asType _: T.Type
) throws -> [(String, T)] {
    var path = "\(MongoSwiftTestCase.specsPath)/\(specName)/tests"
    if let sd = subdirectory {
        path += "/\(sd)"
    }
    return try FileManager.default
        .contentsOfDirectory(atPath: path)
        .filter { $0.hasSuffix(".json") }
        .compactMap { filename in
            guard !excludeFiles.contains(filename) else {
                return nil
            }
            let url = URL(fileURLWithPath: "\(path)/\(filename)")
            let jsonString = try String(contentsOf: url, encoding: .utf8)
            var doc = try ExtendedJSONDecoder().decode(BSONDocument.self, from: jsonString.data(using: .utf8)!)
            doc["name"] = .string(filename)
            return try (filename, BSONDecoder().decode(T.self, from: doc))
        }
}

/// Given two documents, returns a copy of the input document with all keys that *don't*
/// exist in `standard` removed, and with all matching keys put in the same order they
/// appear in `standard`.
public func rearrangeDoc(_ input: BSONDocument, toLookLike standard: BSONDocument) -> BSONDocument {
    var output = BSONDocument()
    for (k, v) in standard {
        switch (v, input[k]) {
        case let (.document(sDoc), .document(iDoc)?):
            output[k] = .document(rearrangeDoc(iDoc, toLookLike: sDoc))
        case let (.array(sArr), .array(iArr)?):
            var newArr: [BSON] = []
            for (i, el) in iArr.enumerated() {
                if let docEl = el.documentValue, let sDoc = sArr[i].documentValue {
                    newArr.append(.document(rearrangeDoc(docEl, toLookLike: sDoc)))
                } else {
                    newArr.append(el)
                }
            }
            output[k] = .array(newArr)
        default:
            output[k] = input[k]
        }
    }
    return output
}

public func fileLevelLog(_ message: String) {
    print("\n------------\n\(message)\n")
}
