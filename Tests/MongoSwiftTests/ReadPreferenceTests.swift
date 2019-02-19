@testable import MongoSwift
import Nimble
import XCTest

final class ReadPreferenceTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testMode() {
        let primary = ReadPreference(.primary)
        expect(primary.mode).to(equal(ReadPreference.Mode.primary))

        let primaryPreferred = ReadPreference(.primaryPreferred)
        expect(primaryPreferred.mode).to(equal(ReadPreference.Mode.primaryPreferred))

        let secondary = ReadPreference(.secondary)
        expect(secondary.mode).to(equal(ReadPreference.Mode.secondary))

        let secondaryPreferred = ReadPreference(.secondaryPreferred)
        expect(secondaryPreferred.mode).to(equal(ReadPreference.Mode.secondaryPreferred))

        let nearest = ReadPreference(.nearest)
        expect(nearest.mode).to(equal(ReadPreference.Mode.nearest))
    }

    func testTagSets() throws {
        let rpNoTagSets = try ReadPreference(.nearest, tagSets: nil)
        expect(rpNoTagSets.tagSets).to(equal([]))

        let rpSomeTagSets = try ReadPreference(.nearest, tagSets: [["dc": "east"], []])
        expect(rpSomeTagSets.tagSets).to(equal([["dc": "east"], []]))

        let rpOnlyEmptyTagSet = try ReadPreference(.nearest, tagSets: [[]])
        expect(rpOnlyEmptyTagSet.tagSets).to(equal([[]]))

        // Non-empty tag sets cannot be combined with primary mode
        expect(try ReadPreference(.primary, tagSets: [["dc": "east"], []]))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try ReadPreference(.primary, tagSets: [[]])).to(throwError(UserError.invalidArgumentError(message: "")))
    }

    func testMaxStalenessSeconds() throws {
        let rpNoMaxStaleness = try ReadPreference(.nearest, maxStalenessSeconds: nil)
        expect(rpNoMaxStaleness.maxStalenessSeconds).to(beNil())

        let rpMinMaxStaleness = try ReadPreference(.nearest, maxStalenessSeconds: 90)
        expect(rpMinMaxStaleness.maxStalenessSeconds).to(equal(90))

        let rpLargeMaxStaleness = try ReadPreference(.nearest, maxStalenessSeconds: 2147483647)
        expect(rpLargeMaxStaleness.maxStalenessSeconds).to(equal(2147483647))

        // maxStalenessSeconds cannot be less than 90
        expect(try ReadPreference(.nearest, maxStalenessSeconds: -1))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try ReadPreference(.nearest, maxStalenessSeconds: 0))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try ReadPreference(.nearest, maxStalenessSeconds: 89))
                .to(throwError(UserError.invalidArgumentError(message: "")))
    }

    func testInitFromPointer() {
        let rpOrig = ReadPreference(.primaryPreferred)
        let rpCopy = ReadPreference(from: rpOrig._readPreference)

        expect(rpCopy).to(equal(rpOrig))
    }

    func testEquatable() throws {
        expect(ReadPreference(.primary)).to(equal(ReadPreference(.primary)))
        expect(ReadPreference(.primary)).toNot(equal(ReadPreference(.primaryPreferred)))
        expect(ReadPreference(.primary)).toNot(equal(ReadPreference(.secondary)))
        expect(ReadPreference(.primary)).toNot(equal(ReadPreference(.secondaryPreferred)))
        expect(ReadPreference(.primary)).toNot(equal(ReadPreference(.nearest)))

        expect(try ReadPreference(.secondary, tagSets: nil))
            .to(equal(ReadPreference(.secondary)))
        expect(try ReadPreference(.secondary, tagSets: []))
            .to(equal(try ReadPreference(.secondary, tagSets: [])))
        expect(try ReadPreference(.secondary, tagSets: [["dc": "east"], []]))
            .to(equal(try ReadPreference(.secondary, tagSets: [["dc": "east"], []])))
        expect(try ReadPreference(.secondary, tagSets: [["dc": "east"], []]))
            .toNot(equal(try ReadPreference(.nearest, tagSets: [["dc": "east"], []])))
        expect(try ReadPreference(.secondary, tagSets: [["dc": "east"], []]))
            .toNot(equal(try ReadPreference(.secondary, maxStalenessSeconds: 90)))

        expect(try ReadPreference(.secondaryPreferred, maxStalenessSeconds: nil))
            .to(equal(ReadPreference(.secondaryPreferred)))
        expect(try ReadPreference(.secondaryPreferred, maxStalenessSeconds: 90))
            .to(equal(try ReadPreference(.secondaryPreferred, maxStalenessSeconds: 90)))
    }
}
