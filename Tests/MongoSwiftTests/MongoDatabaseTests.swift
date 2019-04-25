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

        let indexOpts: Document =
            ["storageEngine": ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document] as Document]
        let doc1: Document = ["_id": 1, "a": "aaa", "b": "bbb"]
        let doc2: Document = ["_id": 2, "a": "abc", "b": "def"]
        let doc3: Document = ["_id": 3, "a": "ghi", "b": "jkl"]

        // test non-view options
        let options = CreateCollectionOptions(
            autoIndexId: true,
            capped: true,
            collation: ["locale": "fr"],
            indexOptionDefaults: indexOpts,
            max: 2,
            size: doc1.rawBSON.count + doc2.rawBSON.count,
            storageEngine: ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document],
            validationAction: "error",
            validationLevel: "moderate",
            validator: ["a": ["$type": "string"] as Document],
            writeConcern: try WriteConcern(w: .majority)
        )

        let collection = try db.createCollection("foo", options: options)
        try collection.insertOne(doc1)

        // should error with a as integer due to validator
        expect(try collection.insertOne(["a": 1])).to(throwError())

        try collection.insertOne(doc2)

        // should overwrite first doc as we've reached max size
        try collection.insertOne(doc3)
        expect(try coll.count()).to(equal(2))

        // test view options
        let viewOptions = CreateCollectionOptions(
            pipeline: [["$project": ["a": 1] as Document]],
            viewOn: "foo"
        )

        let view = try db.createCollection("fooView", options: viewOptions)
        let docs = Array(try view.find(options: FindOptions(sort: ["_id": 1])))
        expect(docs).to(haveCount(2))
        expect(docs[0]).to(equal(["_id": 1, "a": "aaa"]))
        expect(docs[1]).to(equal(["_id": 2, "a": "abc"]))
    }
}
