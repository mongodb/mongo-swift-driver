import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

final class Document_CollectionTests: MongoSwiftTestCase {
    func testIndexLogic() {
        let emptyDoc: Document = [:]

        expect(emptyDoc.startIndex).to(equal(0))
        expect(emptyDoc.endIndex).to(equal(emptyDoc.startIndex))

        let doc: Document = ["a": 3, "b": 4]

        // doc.startIndex, doc.endIndex, doc.index(after:), etc.
        expect(doc.startIndex).to(equal(0))
        expect(doc.endIndex).to(equal(doc.count))
        expect(doc.index(after: doc.index(after: doc.startIndex))).to(equal(doc.endIndex))
        expect(doc[1].key).to(equal("b"))
        expect(doc[1].value).to(equal(4))

        // doc.indices
        expect(doc.indices.count).to(equal(doc.count))
        expect(doc.indices.startIndex).to(equal(doc.startIndex))
        expect(doc.indices[1]).to(equal(doc.index(after: doc.startIndex)))
        expect(doc.indices.endIndex).to(equal(doc.endIndex))

        // doc.first
        let firstElem = doc[doc.startIndex]
        expect(doc.first?.key).to(equal(firstElem.key))
        expect(doc.first?.value).to(equal(firstElem.value))

        // doc.distance
        expect(doc.distance(from: doc.startIndex, to: doc.endIndex)).to(equal(doc.count))
        expect(doc.distance(from: doc.index(after: doc.startIndex), to: doc.endIndex)).to(equal(doc.count - 1))

        // doc.formIndex
        var firstIndex = 0
        doc.formIndex(after: &firstIndex)
        expect(firstIndex).to(equal(doc.index(after: doc.startIndex)))

        // doc.index(offsetBy:), doc.index(offsetBy:,limitedBy:)
        expect(doc.index(doc.startIndex, offsetBy: 2)).to(equal(doc.endIndex))
        expect(doc.index(doc.startIndex, offsetBy: 2, limitedBy: doc.endIndex)).to(equal(doc.endIndex))
        expect(doc.index(doc.startIndex, offsetBy: 99, limitedBy: 1)).to(beNil())

        // firstIndex(where:)
        expect(doc.firstIndex { $0.key == "a" && $0.value == 3 }).to(equal(doc.startIndex))
    }

    func testMutators() throws {
        var doc: Document = ["a": 3, "b": 2, "c": 5, "d": 4]

        // doc.removeFirst
        let firstElem = doc.removeFirst()
        expect(firstElem.key).to(equal("a"))
        expect(firstElem.value).to(equal(3))
        expect(doc).to(equal(["b": 2, "c": 5, "d": 4]))

        // doc.removeFirst(k:)
        doc.removeFirst(2)
        expect(doc).to(equal(["d": 4]))

        // doc.popFirst
        let lastElem = doc.popFirst()
        expect(lastElem?.key).to(equal("d"))
        expect(lastElem?.value).to(equal(4))
        expect(doc).to(equal([:]))

        // doc.merge
        let newDoc: Document = ["e": 4, "f": 2]
        try doc.merge(newDoc)
    }

    func testPrefixSuffix() {
        let doc: Document = ["a": 3, "b": 2, "c": 5, "d": 4, "e": 3]

        let upToPrefixDoc = doc.prefix(upTo: 2)
        let throughPrefixDoc = doc.prefix(through: 1)
        let suffixDoc = doc.suffix(from: 1)

        // doc.prefix(upTo:)
        expect(upToPrefixDoc).to(equal(["a": 3, "b": 2]))

        // doc.prefix(through:)
        expect(throughPrefixDoc).to(equal(["a": 3, "b": 2]))

        // doc.suffix
        expect(suffixDoc).to(equal(["b": 2, "c": 5, "d": 4, "e": 3]))
    }

    func testIndexSubscript() {
        let doc: Document = ["hello": "world", "swift": 4.2, "null": .null]

        // subscript with index position
        expect(doc[0].value).to(equal("world"))
        expect(doc[1].value).to(equal(4.2))
        expect(doc[2].value).to(equal(.null))

        // subscript with index bounds
        expect(doc[0..<0]).to(equal([:]))
        expect(doc[0..<1]).to(equal(["hello": "world"]))
        expect(doc[0..<2]).to(equal(["hello": "world", "swift": 4.2]))
        expect(doc[0..<3]).to(equal(doc))
    }
}
