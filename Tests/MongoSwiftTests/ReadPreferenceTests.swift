@testable import MongoSwift
import Nimble
import XCTest

final class ReadPreferenceTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testMode() {
        let defaultPref = ReadPreference()
        expect(defaultPref.mode).to(equal(ReadPreference.Mode.primary))

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

    func testOperationReadPreference() throws {
        // setup a collection
        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        let command: Document = ["count": coll.name]

        // expect runCommand to return a success response when passing in a valid read preference
        let opts = RunCommandOptions(readPreference: ReadPreference(.secondaryPreferred))
        let res = try db.runCommand(command, options: opts)
        expect((res["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        // expect running other commands to not throw errors when passing in a valid read preference
        expect(try coll.find(options: FindOptions(readPreference: ReadPreference()))).toNot(throwError())

        expect(try coll.aggregate([["$project": ["a": 1] as Document]],
                                  options: AggregateOptions(readPreference: ReadPreference(.secondaryPreferred))))
                                  .toNot(throwError())

        expect(try coll.count(options: CountOptions(readPreference: ReadPreference(.secondaryPreferred))))
                                        .toNot(throwError())

        expect(try coll.distinct(fieldName: "a",
                                 options: DistinctOptions(readPreference: ReadPreference(.secondaryPreferred))))
                                 .toNot(throwError())
    }

    func testClientReadPreference() throws {
        let primaryPreferred = ReadPreference(.primaryPreferred)
        let secondary = ReadPreference(.secondary)

        do {
            // expect that a client with an unset read preference has it default to primary
            let client = try MongoClient.makeTestClient()
            expect(client.readPreference).to(equal(ReadPreference()))

            // expect that a database created from this client inherits its read preference
            let db1 = client.db(type(of: self).testDatabase)
            expect(db1.readPreference).to(equal(ReadPreference()))

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: secondary)
            let db2 = client.db(type(of: self).testDatabase, options: opts)
            expect(db2.readPreference).to(equal(ReadPreference(.secondary)))
        }

        do {
            let client = try MongoClient(options: ClientOptions(readPreference: primaryPreferred))
            expect(client.readPreference).to(equal(ReadPreference(.primaryPreferred)))

            // expect that a database created from this client inherits its read preference
            let db1 = client.db(type(of: self).testDatabase)
            expect(db1.readPreference).to(equal(ReadPreference(.primaryPreferred)))

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: secondary)
            let db2 = client.db(type(of: self).testDatabase, options: opts)
            expect(db2.readPreference).to(equal(ReadPreference(.secondary)))
        }
    }

    func testDatabaseReadPreference() throws {
        let primary = ReadPreference(.primary)
        let secondary = ReadPreference(.secondary)
        let client = try MongoClient.makeTestClient()

        do {
            // expect that a database with an unset read preference defaults to primary
            let db = client.db(type(of: self).testDatabase)
            expect(db.readPreference).to(equal(ReadPreference(.primary)))

             // expect that a collection inherits its database default read preference
            let coll1 = db.collection(self.getCollectionName(suffix: "1"))
            expect(coll1.readPreference).to(equal(ReadPreference(.primary)))

            // expect that a collection can override its inherited read preference
            let coll2 = db.collection(self.getCollectionName(suffix: "2"),
                                      options: CollectionOptions(readPreference: secondary))
            expect(coll2.readPreference).to(equal(ReadPreference(.secondary)))
        }

        do {
            // expect that a collection inherits its database read preference
            let db = client.db(type(of: self).testDatabase, options: DatabaseOptions(readPreference: secondary))
            let coll1 = db.collection(self.getCollectionName(suffix: "1"))
            expect(coll1.readPreference).to(equal(ReadPreference(.secondary)))

            // expect that a collection can override its database read preference
            let coll2 = db.collection(self.getCollectionName(suffix: "2"),
                                      options: CollectionOptions(readPreference: primary))
            expect(coll2.readPreference).to(equal(ReadPreference(.primary)))
        }
    }
}
