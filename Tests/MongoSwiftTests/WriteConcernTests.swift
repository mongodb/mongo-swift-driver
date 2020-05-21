@testable import MongoSwift
import Nimble
import TestsCommon

/// Indicates that a type has a write concern property, as well as a way to get a write concern from an instance of the
/// corresponding mongoc type.
private protocol WriteConcernable {
    var writeConcern: WriteConcern? { get }
    func getMongocWriteConcern() throws -> WriteConcern?
}

extension MongoClient: WriteConcernable {}
extension MongoDatabase: WriteConcernable {}
extension MongoCollection: WriteConcernable {}

/// Checks that a type T, as well as pointers to corresponding libmongoc instances, has the expected write concern.
private func checkWriteConcern<T: WriteConcernable>(
    _ instance: T,
    _ expected: WriteConcern,
    _ description: String
) throws {
    if expected.isDefault {
        expect(instance.writeConcern).to(beNil(), description: description)
    } else {
        expect(instance.writeConcern).to(equal(expected), description: description)
    }

    expect(try instance.getMongocWriteConcern()).to(equal(expected))
}

final class WriteConcernTests: MongoSwiftTestCase {
    func testWriteConcernType() throws {
        // try creating write concerns with various valid options
        expect(try WriteConcern(w: .number(0))).toNot(throwError())
        expect(try WriteConcern(w: .number(3))).toNot(throwError())
        expect(try WriteConcern(journal: true, w: .number(1))).toNot(throwError())
        expect(try WriteConcern(w: .number(0), wtimeoutMS: 1000)).toNot(throwError())
        expect(try WriteConcern(w: .custom("hi"))).toNot(throwError())
        expect(try WriteConcern(w: .majority)).toNot(throwError())

        // verify that this combination is considered invalid
        expect(try WriteConcern(journal: true, w: .number(0)))
            .to(throwError(errorType: InvalidArgumentError.self))

        // verify that a negative value for w or for wtimeoutMS is considered invalid
        expect(try WriteConcern(w: .number(-1)))
            .to(throwError(errorType: InvalidArgumentError.self))
        expect(try WriteConcern(wtimeoutMS: -1))
            .to(throwError(errorType: InvalidArgumentError.self))
    }

    func testClientWriteConcern() throws {
        let w1 = try WriteConcern(w: .number(1))
        let w2 = try WriteConcern(w: .number(2))
        let empty = WriteConcern.serverDefault

        // test behavior of a client with initialized with no WC
        try self.withTestClient { client in
            let clientDesc = "client created with no WC provided"
            // expect the readConcern property to exist and be default
            try checkWriteConcern(client, empty, clientDesc)

            // expect that a DB created from this client inherits its default WC
            let db1 = client.db(Self.testDatabase)
            try checkWriteConcern(db1, empty, "db created with no WC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's default WC
            let db2 = client.db(Self.testDatabase, options: MongoDatabaseOptions(writeConcern: w2))
            try checkWriteConcern(db2, w2, "db created with w:2 from \(clientDesc)")
        }

        // test behavior of a client with w: 1
        try self.withTestClient(options: MongoClientOptions(writeConcern: w1)) { client in
            let clientDesc = "client created with w:1"
            // although w:1 is default, if it is explicitly provided it should be set
            try checkWriteConcern(client, w1, clientDesc)

            // expect that a DB created from this client inherits its WC
            let db1 = client.db(Self.testDatabase)
            try checkWriteConcern(db1, w1, "db created with no WC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's WC
            let db2 = client.db(Self.testDatabase, options: MongoDatabaseOptions(writeConcern: w2))
            try checkWriteConcern(db2, w2, "db created with w:2 from \(clientDesc)")
        }

        // test behavior of a client with w: 2
        try self.withTestClient(options: MongoClientOptions(writeConcern: w2)) { client in
            let clientDesc = "client created with w:2"
            try checkWriteConcern(client, w2, clientDesc)

            // expect that a DB created from this client can override the client's WC with an unset one
            let db = client.db(
                Self.testDatabase,
                options: MongoDatabaseOptions(writeConcern: empty)
            )
            try checkWriteConcern(db, empty, "db created with empty WC from \(clientDesc)")
        }
    }

    func testDatabaseWriteConcern() throws {
        let empty = WriteConcern.serverDefault
        let w1 = try WriteConcern(w: .number(1))
        let w2 = try WriteConcern(w: .number(2))

        try self.withTestClient { client in
            let db1 = client.db(Self.testDatabase)
            defer { try? db1.drop().wait() }

            var dbDesc = "db created with no WC provided"

            // expect that a collection created from a DB with default WC also has default WC
            var coll1 = try db1.createCollection(self.getCollectionName(suffix: "1")).wait()
            try checkWriteConcern(coll1, empty, "collection created with no WC provided from \(dbDesc)")

            // expect that a collection retrieved from a DB with default WC also has default WC
            coll1 = db1.collection(coll1.name)
            try checkWriteConcern(coll1, empty, "collection retrieved with no WC provided from \(dbDesc)")

            // expect that a collection retrieved from a DB with default WC can override the DB's WC
            let coll2 =
                db1.collection(self.getCollectionName(suffix: "2"), options: MongoCollectionOptions(writeConcern: w1))
            try checkWriteConcern(coll2, w1, "collection retrieved with w:1 from \(dbDesc)")

            try db1.drop().wait()

            let db2 = client.db(Self.testDatabase, options: MongoDatabaseOptions(writeConcern: w1))
            defer { try? db2.drop().wait() }
            dbDesc = "db created with w:1"

            // expect that a collection created from a DB with w:1 also has w:1
            var coll3 = try db2.createCollection(self.getCollectionName(suffix: "3")).wait()
            try checkWriteConcern(coll3, w1, "collection created with no WC provided from \(dbDesc)")

            // expect that a collection retrieved from a DB with w:1 also has w:1
            coll3 = db2.collection(coll3.name)
            try checkWriteConcern(coll3, w1, "collection retrieved with no WC provided from \(dbDesc)")

            // expect that a collection retrieved from a DB with w:1 can override the DB's WC
            let coll4 =
                db2.collection(self.getCollectionName(suffix: "4"), options: MongoCollectionOptions(writeConcern: w2))
            try checkWriteConcern(coll4, w2, "collection retrieved with w:2 from \(dbDesc)")
        }
    }

    func testRoundTripThroughLibmongoc() throws {
        let wcs: [WriteConcern] = [
            .serverDefault,
            try WriteConcern(w: .number(2)),
            try WriteConcern(w: .custom("hi")),
            .majority,
            try WriteConcern(journal: true),
            try WriteConcern(wtimeoutMS: 200)
        ]

        for original in wcs {
            let copy = original.withMongocWriteConcern { wcPtr in
                WriteConcern(copying: wcPtr)
            }
            expect(copy).to(equal(original))
        }
    }
}
