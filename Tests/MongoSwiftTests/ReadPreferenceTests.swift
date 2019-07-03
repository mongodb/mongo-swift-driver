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

    func testOperationReadPreference() throws {
        // setup a collection
        let client = try MongoClient()
        let db = client.db("myDb")
        defer { try? db.drop() }
        let coll = try db.createCollection("myCollection")

        let command: Document = ["count": coll.name]

        // run the command with a valid read preference
        let opts1 = RunCommandOptions(readPreference: ReadPreference(.primary))
        let res1 = try db.runCommand(command, options: opts1)
        expect((res1["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        // run the command with an empty read preference
        let opts2 = RunCommandOptions()
        let res2 = try db.runCommand(command, options: opts2)
        expect((res2["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        expect(try coll.find(options: FindOptions(readPreference: ReadPreference(.primary)))).toNot(throwError())

        expect(try coll.aggregate([["$project": ["a": 1] as Document]],
                                  options: AggregateOptions(readPreference: ReadPreference(.secondary))))
                                  .toNot(throwError())

        expect(try coll.count(options: CountOptions(readPreference: ReadPreference(.primary)))).toNot(throwError())

        expect(try coll.distinct(fieldName: "a",
                                 options: DistinctOptions(readPreference: ReadPreference(.primary))))
                                 .toNot(throwError())
    }

    func testClientReadPreference() throws {
        let primary = ReadPreference(.primary)
        let primaryPreferred = ReadPreference(.primaryPreferred)
        let secondary = ReadPreference(.secondary)

        do {
            // expect that a client with an unset read preferences has it default to primary
            let client1 = try MongoClient()
            expect(client1.readPreference.mode).to(equal(.primary))

            // expect that a database created from this client inherits its read preferences
            let db1 = client1.db("myDB")
            expect(db1.readPreference.mode).to(equal(.primary))

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: secondary)
            let db2 = client1.db("myDB", options: opts)
            expect(db2.readPreference.mode).to(equal(.secondary))
        }

        do {
            let client2 = try MongoClient(options: ClientOptions(readPreference: primaryPreferred))
            expect(client2.readPreference.mode).to(equal(.primaryPreferred))

            // expect that a database created from this client inherits its read preferences
            let db1 = client2.db("myDB")
            expect(db1.readPreference.mode).to(equal(.primaryPreferred))

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: secondary)
            let db2 = client2.db("myDB", options: opts)
            expect(db2.readPreference.mode).to(equal(.secondary))
        }
    }

    func testDatabaseReadPreference() throws {
        let primary = ReadPreference(.primary)
        let primaryPreferred = ReadPreference(.primaryPreferred)
        let secondary = ReadPreference(.secondary)
        let client = try MongoClient()

        do {
            // expect that a database with an unset read preferences defaults to primary
            let db1 = client.db("myDb")
            expect(db1.readPreference.mode).to(equal(.primary))

             // expect that a collection inherits its database default read preferences
            let coll1 = db1.collection("coll1")
            expect(coll1.readPreference.mode).to(equal(.primary))

            // expect that a collection can override its inherited read preferences
            let coll2 = db1.collection("coll2", options: CollectionOptions(readPreference: secondary))
            expect(coll2.readPreference.mode).to(equal(.secondary))
        }

        do {
            // expect that a collection inherits its database read preferences
            let db2 = client.db("myDB", options: DatabaseOptions(readPreference: secondary))
            let coll1 = db2.collection("coll1")
            expect(coll1.readPreference.mode).to(equal(.secondary))

            // expect that a collection can override its database read preferences
            let coll2 = db2.collection("coll2", options: CollectionOptions(readPreference: primary))
            expect(coll2.readPreference.mode).to(equal(.primary))
        }
    }
}
