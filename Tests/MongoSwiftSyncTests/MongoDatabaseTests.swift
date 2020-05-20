import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon

final class MongoDatabaseTests: MongoSwiftTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        guard let client = try? MongoClient.makeTestClient() else {
            return
        }
        try? client.db(Self.testDatabase).drop()
    }

    func testMongoDatabase() throws {
        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)

        let command: Document = ["create": .string(self.getCollectionName(suffix: "1"))]
        let res = try db.runCommand(command)
        expect(res["ok"]?.asDouble()).to(equal(1.0))
        expect(try (Array(db.listCollections())).count).to(equal(1))

        // create collection using createCollection
        expect(try db.createCollection(self.getCollectionName(suffix: "2"))).toNot(throwError())
        expect(try (Array(db.listCollections())).count).to(equal(2))
        expect(try db.listCollections(["type": "view"])).to(beEmpty())

        expect(try db.drop()).toNot(throwError())
        let names = try client.listDatabaseNames()
        expect(names).toNot(contain([Self.testDatabase]))

        expect(db.name).to(equal(Self.testDatabase))

        // error code 59: CommandNotFound
        expect(try db.runCommand(["asdfsadf": .objectID(BSONObjectID())]))
            .to(throwError(CommandError.new(
                code: 59,
                codeName: "CommandNotFound",
                message: "",
                errorLabels: nil
            )))
    }

    func testDropDatabase() throws {
        let encoder = BSONEncoder()

        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()
        let db = client.db(Self.testDatabase)

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        let expectedWriteConcerns: [WriteConcern] = [
            try WriteConcern(journal: true, w: .number(1)),
            try WriteConcern(journal: true, w: .number(1), wtimeoutMS: 123)
        ]

        try monitor.captureEvents {
            for wc in expectedWriteConcerns {
                expect(try db.drop(options: DropDatabaseOptions(writeConcern: wc))).toNot(throwError())
            }
        }

        let receivedEvents = monitor.commandStartedEvents()
        expect(receivedEvents).to(haveCount(expectedWriteConcerns.count))

        for (i, event) in receivedEvents.enumerated() {
            expect(event.command["dropDatabase"]).toNot(beNil())
            let expectedWriteConcern = try? encoder.encode(expectedWriteConcerns[i])
            expect(event.command["writeConcern"]?.documentValue).to(sortedEqual(expectedWriteConcern))
        }
    }

    func testCreateCollection() throws {
        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)

        let indexOpts: Document =
            ["storageEngine": ["wiredTiger": ["configString": "access_pattern_hint=random"]]]

        // test non-view options
        let fooOptions = CreateCollectionOptions(
            capped: true,
            collation: ["locale": "fr"],
            indexOptionDefaults: indexOpts,
            max: 1000,
            size: 10240,
            storageEngine: ["wiredTiger": ["configString": "access_pattern_hint=random"]],
            validationAction: "warn",
            validationLevel: "moderate",
            validator: ["phone": ["$type": "string"]],
            writeConcern: .majority
        )
        expect(try db.createCollection("foo", options: fooOptions)).toNot(throwError())

        // test view options
        let viewOptions = CreateCollectionOptions(
            pipeline: [["$project": ["a": 1]]],
            viewOn: "foo"
        )
        expect(try db.createCollection("fooView", options: viewOptions)).toNot(throwError())

        var collectionInfo = try Array(db.listCollections().all())
        collectionInfo.sort { $0.name < $1.name }
        expect(collectionInfo).to(haveCount(3))

        let fooInfo = CollectionSpecificationInfo.new(readOnly: false, uuid: UUID())
        let fooIndex = IndexModel(keys: ["_id": 1] as Document, options: IndexOptions(name: "_id_"))
        let expectedFoo = CollectionSpecification.new(
            name: "foo",
            type: .collection,
            options: fooOptions,
            info: fooInfo,
            idIndex: fooIndex
        )
        expect(collectionInfo[0]).to(equal(expectedFoo))

        let viewInfo = CollectionSpecificationInfo.new(readOnly: true, uuid: nil)
        let expectedView = CollectionSpecification.new(
            name: "fooView",
            type: .view,
            options: viewOptions,
            info: viewInfo,
            idIndex: nil
        )
        expect(collectionInfo[1]).to(equal(expectedView))

        expect(collectionInfo[2].name).to(equal("system.views"))
    }

    func testListCollections() throws {
        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()
        let db = client.db(Self.testDatabase)
        try db.drop()

        let cappedOptions = CreateCollectionOptions(capped: true, max: 1000, size: 10240)
        let uncappedOptions = CreateCollectionOptions(capped: false)

        _ = try db.createCollection("capped", options: cappedOptions)
        _ = try db.createCollection("uncapped", options: uncappedOptions)
        try db.collection("capped").insertOne(["a": 1])
        try db.collection("uncapped").insertOne(["b": 2])

        try monitor.captureEvents {
            var collectionNames = try db.listCollectionNames()
            collectionNames.sort { $0 < $1 }

            expect(collectionNames).to(haveCount(2))
            expect(collectionNames[0]).to(equal("capped"))
            expect(collectionNames[1]).to(equal("uncapped"))

            let filteredCollectionNames = try db.listCollectionNames(["name": "nonexistent"])
            expect(filteredCollectionNames).to(haveCount(0))

            let cappedNames = try db.listCollectionNames(["options.capped": true])
            expect(cappedNames).to(haveCount(1))
            expect(cappedNames[0]).to(equal("capped"))

            let mongoCollections = try db.listMongoCollections(["options.capped": true])
            expect(mongoCollections).to(haveCount(1))
            expect(mongoCollections[0].name).to(equal("capped"))
        }

        // Check nameOnly flag passed to server for respective listCollection calls.
        let listNamesEvents = monitor.commandStartedEvents(withNames: ["listCollections"])
        expect(listNamesEvents).to(haveCount(4))
        expect(listNamesEvents[0].command["nameOnly"]).to(equal(true))
        expect(listNamesEvents[1].command["nameOnly"]).to(equal(true))
        expect(listNamesEvents[2].command["nameOnly"]).to(equal(false))
        expect(listNamesEvents[3].command["nameOnly"]).to(equal(false))
    }
}

extension CreateCollectionOptions: Equatable {
    // This omits the coding strategy properties (they're not sent to/stored on the server so would not be
    // round-tripped), along with `writeConcern`, since that is used only for the "create" command itself
    // and is not a property of the collection.
    public static func == (lhs: CreateCollectionOptions, rhs: CreateCollectionOptions) -> Bool {
        rhs.capped == lhs.capped &&
            lhs.size == rhs.size &&
            lhs.max == rhs.max &&
            lhs.storageEngine == rhs.storageEngine &&
            lhs.validator == rhs.validator &&
            lhs.validationLevel == rhs.validationLevel &&
            lhs.validationAction == rhs.validationAction &&
            lhs.indexOptionDefaults == rhs.indexOptionDefaults &&
            lhs.viewOn == rhs.viewOn &&
            lhs.pipeline == rhs.pipeline &&
            lhs.collation?["locale"] == rhs.collation?["locale"]
        // ^ server adds a bunch of extra fields and a version number
        // to collations. rather than deal with those, just verify the
        // locale matches.
    }
}

extension CollectionSpecification: Equatable {
    public static func == (lhs: CollectionSpecification, rhs: CollectionSpecification) -> Bool {
        lhs.name == rhs.name &&
            lhs.type == rhs.type &&
            lhs.options == rhs.options &&
            lhs.info.readOnly == rhs.info.readOnly &&
            lhs.idIndex?.options?.name == rhs.idIndex?.options?.name
    }
}
