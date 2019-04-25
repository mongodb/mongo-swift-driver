@testable import MongoSwift
import Nimble
import XCTest

final class MongoDatabaseTests: MongoSwiftTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMongoDatabase() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let db = client.db(type(of: self).testDatabase)

        let command: Document = ["create": self.getCollectionName(suffix: "1")]
        let res = try db.runCommand(command)
        expect((res["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))
        expect(try (Array(db.listCollections()) as [Document]).count).to(equal(1))

        // create collection using createCollection
        expect(try db.createCollection(self.getCollectionName(suffix: "2"))).toNot(throwError())
        expect(try (Array(db.listCollections()) as [Document]).count).to(equal(2))

        let opts = ListCollectionsOptions(filter: ["type": "view"] as Document)
        expect(try db.listCollections(options: opts)).to(beEmpty())

        expect(try db.drop()).toNot(throwError())
        let dbs = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        let names = (Array(dbs) as [Document]).map { $0["name"] as? String ?? "" }
        expect(names).toNot(contain([type(of: self).testDatabase]))

        expect(db.name).to(equal(type(of: self).testDatabase))

        // error code 59: CommandNotFound
        expect(try db.runCommand(["asdfsadf": ObjectId()]))
                .to(throwError(ServerError.commandError(code: 59, message: "", errorLabels: nil)))
    }

    func testCreateCollection() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        // test non-view options
        let options = CreateCollectionOptions(
            autoIndexId: true,
            capped: true,
            collation: ["locale": "fr"],
            indexOptionDefaults: ["storageEngine": ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document] as Document],
            max: 1000,
            size: 10000,
            storageEngine: ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document],
            validationAction: "warn",
            validationLevel: "moderate",
            validator: ["phone": ["$type": "string"] as Document],
            writeConcern: try WriteConcern(w: .majority)
        )
        expect(try db.createCollection("foo", options: options)).toNot(throwError())

        // test view options
        let viewOptions = CreateCollectionOptions(
            pipeline: [["$project": ["a": 1] as Document]],
            viewOn: "foo"
        )

        expect(try db.createCollection("fooView", options: viewOptions)).toNot(throwError())
    }
}
