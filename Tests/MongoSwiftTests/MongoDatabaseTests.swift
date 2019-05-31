@testable import MongoSwift
import Nimble
import XCTest

final class MongoDatabaseTests: MongoSwiftTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        guard let client = try? MongoClient(MongoSwiftTestCase.connStr) else {
            return
        }
        try? client.db(type(of: self).testDatabase).drop()
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

    func testDropDatabase() throws {
        let encoder = BSONEncoder()

        let center = NotificationCenter.default

        let client = try MongoClient(options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring(forEvents: .commandMonitoring)

        var db = client.db(type(of: self).testDatabase)
        var writeConcern = try WriteConcern(journal: true, w: .number(1))
    
        let observer = center.addObserver(forName: nil, object: nil, queue: nil) { notif in
            print(notif)
        }

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        var opts = DropDatabaseOptions(writeConcern: writeConcern)
        expect(try db.drop(options: opts)).toNot(throwError())

        db = client.db(type(of: self).testDatabase)
        writeConcern = try WriteConcern(journal: true, w: .number(1), wtimeoutMS: 123)
        opts = DropDatabaseOptions(writeConcern: writeConcern)
        expect(try db.drop(options: opts)).toNot(throwError())

        center.removeObserver(observer)
    }

    func testCreateCollection() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let db = client.db(type(of: self).testDatabase)

        let indexOpts: Document =
            ["storageEngine": ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document] as Document]

        // test non-view options
        let fooOptions = CreateCollectionOptions(
            autoIndexId: true,
            capped: true,
            collation: ["locale": "fr"],
            indexOptionDefaults: indexOpts,
            max: 1000,
            size: 10240,
            storageEngine: ["wiredTiger": ["configString": "access_pattern_hint=random"] as Document],
            validationAction: "warn",
            validationLevel: "moderate",
            validator: ["phone": ["$type": "string"] as Document],
            writeConcern: try WriteConcern(w: .majority)
        )
        expect(try db.createCollection("foo", options: fooOptions)).toNot(throwError())

        // test view options
        let viewOptions = CreateCollectionOptions(
            pipeline: [["$project": ["a": 1] as Document]],
            viewOn: "foo"
        )

        expect(try db.createCollection("fooView", options: viewOptions)).toNot(throwError())

        let decoder = BSONDecoder()
        var collectionInfo = try db.listCollections().map { try decoder.decode(CollectionInfo.self, from: $0) }
        collectionInfo.sort { $0.name < $1.name }

        expect(collectionInfo).to(haveCount(3))

        let expectedFoo = CollectionInfo(name: "foo", type: "collection", options: fooOptions)
        expect(collectionInfo[0]).to(equal(expectedFoo))

        let expectedView = CollectionInfo(name: "fooView", type: "view", options: viewOptions)
        expect(collectionInfo[1]).to(equal(expectedView))

        expect(collectionInfo[2].name).to(equal("system.views"))
    }
}

struct CollectionInfo: Decodable, Equatable {
    let name: String
    let type: String
    let options: CreateCollectionOptions
}

extension CreateCollectionOptions: Equatable {
    // This omits the coding strategy properties (they're not sent to/stored on the server so would not be
    // round-tripped), along with `writeConcern`, since that is used only for the "create" command itself
    // and is not a property of the collection.
    public static func == (lhs: CreateCollectionOptions, rhs: CreateCollectionOptions) -> Bool {
        return rhs.capped == lhs.capped &&
               rhs.autoIndexId == lhs.autoIndexId &&
               lhs.size == rhs.size &&
               lhs.max == rhs.max &&
               lhs.storageEngine == rhs.storageEngine &&
               lhs.validator == rhs.validator &&
               lhs.validationLevel == rhs.validationLevel &&
               lhs.validationAction == rhs.validationAction &&
               lhs.indexOptionDefaults == rhs.indexOptionDefaults &&
               lhs.viewOn == rhs.viewOn &&
               lhs.pipeline == rhs.pipeline &&
               lhs.collation?["locale"] as? String == rhs.collation?["locale"] as? String
               // ^ server adds a bunch of extra fields and a version number
               // to collations. rather than deal with those, just verify the
               // locale matches.
    }
}
