@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

/// Indicates that a type has a read preference property, as well as a way to get a read preference from an instance
/// of the corresponding mongoc type.
private protocol ReadPreferenceable {
    var readPreference: ReadPreference { get }
    func getMongocReadPreference() throws -> ReadPreference
}

extension MongoClient: ReadPreferenceable {}
extension MongoDatabase: ReadPreferenceable {}
extension MongoCollection: ReadPreferenceable {}

/// Checks that a type T, as well as pointers to corresponding libmongoc instances, has the expected read preference.
private func checkReadPreference<T: ReadPreferenceable>(
    _ instance: T,
    _ expected: ReadPreference,
    _ description: String
) throws {
    expect(instance.readPreference).to(equal(expected), description: description)
    expect(try instance.getMongocReadPreference()).to(equal(expected))
}

final class ReadPreferenceTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testMode() {
        expect(ReadPreference.primary.mode).to(equal(.primary))
        expect(ReadPreference.primaryPreferred.mode).to(equal(.primaryPreferred))
        expect(ReadPreference.secondary.mode).to(equal(.secondary))
        expect(ReadPreference.secondaryPreferred.mode).to(equal(.secondaryPreferred))
        expect(ReadPreference.nearest.mode).to(equal(.nearest))
    }

    func testTagSets() throws {
        expect(ReadPreference.nearest.tagSets).to(beNil())

        let rpTagSets = try ReadPreference.nearest(tagSets: [["dc": "east"], [:]])
        expect(rpTagSets.tagSets).to(equal([["dc": "east"], [:]]))

        let rpOnlyEmptyTagSet = try ReadPreference.nearest(tagSets: [[:]])
        expect(rpOnlyEmptyTagSet.tagSets).to(equal([[:]]))
    }

    func testMaxStalenessSeconds() throws {
        expect(ReadPreference.nearest.maxStalenessSeconds).to(beNil())

        let rpMinMaxStaleness = try ReadPreference.nearest(maxStalenessSeconds: 90)
        expect(rpMinMaxStaleness.maxStalenessSeconds).to(equal(90))

        let rpLargeMaxStaleness = try ReadPreference.nearest(maxStalenessSeconds: 2_147_483_647)
        expect(rpLargeMaxStaleness.maxStalenessSeconds).to(equal(2_147_483_647))

        // maxStalenessSeconds cannot be less than 90
        expect(try ReadPreference.nearest(maxStalenessSeconds: -1))
            .to(throwError(errorType: InvalidArgumentError.self))
        expect(try ReadPreference.nearest(maxStalenessSeconds: 0))
            .to(throwError(errorType: InvalidArgumentError.self))
        expect(try ReadPreference.nearest(maxStalenessSeconds: 89))
            .to(throwError(errorType: InvalidArgumentError.self))
    }

    func testInitFromPointer() {
        let rpOrig = ReadPreference.primaryPreferred
        let rpCopy = rpOrig.withMongocReadPreference { origPtr in
            ReadPreference(copying: origPtr)
        }
        expect(rpCopy).to(equal(rpOrig))
    }

    func testEquatable() throws {
        expect(ReadPreference.primary).to(equal(.primary))
        expect(ReadPreference.primary).toNot(equal(.primaryPreferred))
        expect(ReadPreference.primary).toNot(equal(.secondary))
        expect(ReadPreference.primary).toNot(equal(.secondaryPreferred))
        expect(ReadPreference.primary).toNot(equal(.nearest))

        expect(try ReadPreference.secondary(tagSets: nil))
            .to(equal(.secondary))
        expect(try ReadPreference.secondary(tagSets: []))
            .to(equal(try ReadPreference.secondary(tagSets: [])))
        expect(try ReadPreference.secondary(tagSets: [["dc": "east"], [:]]))
            .to(equal(try ReadPreference.secondary(tagSets: [["dc": "east"], [:]])))
        expect(try ReadPreference.secondary(tagSets: [["dc": "east"], [:]]))
            .toNot(equal(try ReadPreference.nearest(tagSets: [["dc": "east"], [:]])))
        expect(try ReadPreference.secondary(tagSets: [["dc": "east"], [:]]))
            .toNot(equal(try ReadPreference.secondary(maxStalenessSeconds: 90)))

        expect(try ReadPreference.secondaryPreferred(maxStalenessSeconds: nil))
            .to(equal(.secondaryPreferred))
        expect(try ReadPreference.secondaryPreferred(maxStalenessSeconds: 90))
            .to(equal(try ReadPreference.secondaryPreferred(maxStalenessSeconds: 90)))
    }

    func testClientReadPreference() throws {
        try self.withTestClient { client in
            let clientDesc = "client created with no RP provided"
            // expect that a client with an unset read preference has it default to primary
            try checkReadPreference(client, .primary, clientDesc)

            // expect that a database created from this client inherits its read preference
            let db1 = client.db(Self.testDatabase)
            try checkReadPreference(db1, .primary, "db created with no RP provided from \(clientDesc)")

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: .secondary)
            let db2 = client.db(Self.testDatabase, options: opts)
            try checkReadPreference(db2, .secondary, "db created with secondary RP from \(clientDesc)")
        }

        try self.withTestClient(options: ClientOptions(readPreference: .primaryPreferred)) { client in
            let clientDesc = "client created with RP primaryPreferred"
            try checkReadPreference(client, .primaryPreferred, clientDesc)

            // expect that a database created from this client inherits its read preference
            let db1 = client.db(Self.testDatabase)
            try checkReadPreference(db1, .primaryPreferred, "db created with no RP provided from \(clientDesc)")

            // expect that a database can override the readPreference it inherited from a client
            let opts = DatabaseOptions(readPreference: .secondary)
            let db2 = client.db(Self.testDatabase, options: opts)
            try checkReadPreference(db2, .secondary, "db created with secondary RP from \(clientDesc)")
        }
    }

    func testDatabaseReadPreference() throws {
        try self.withTestClient { client in
            do {
                // expect that a database with an unset read preference defaults to primary
                let dbDesc = "db created with no RP provided"
                let db = client.db(Self.testDatabase)
                try checkReadPreference(db, .primary, dbDesc)

                // expect that a collection inherits its database default read preference
                let coll1 = db.collection(self.getCollectionName(suffix: "1"))
                try checkReadPreference(coll1, .primary, "coll created with no RP provided from \(dbDesc)")

                // expect that a collection can override its inherited read preference
                let coll2 = db.collection(
                    self.getCollectionName(suffix: "2"),
                    options: CollectionOptions(readPreference: .secondary)
                )
                try checkReadPreference(coll2, .secondary, "coll created with secondary RP from \(dbDesc)")
            }

            do {
                // expect that a collection inherits its database read preference
                let dbDesc = "db created with secondary RP"
                let db = client.db(Self.testDatabase, options: DatabaseOptions(readPreference: .secondary))
                let coll1 = db.collection(self.getCollectionName(suffix: "1"))
                try checkReadPreference(coll1, .secondary, "coll created with no RP provided from \(dbDesc)")

                // expect that a collection can override its database read preference
                let coll2 = db.collection(
                    self.getCollectionName(suffix: "2"),
                    options: CollectionOptions(readPreference: .primary)
                )
                try checkReadPreference(coll1, .secondary, "coll created with secondary RP from \(dbDesc)")
            }
        }
    }
}
