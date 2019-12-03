@testable import MongoSwift
import Nimble
import XCTest

final class MongoDatabaseTests: MongoSwiftTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        guard let client = try? MongoClient.makeTestClient() else {
            return
        }
        try? client.db(type(of: self).testDatabase).drop()
    }

    func testMongoDatabase() throws {
        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)

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
        expect(names).toNot(contain([type(of: self).testDatabase]))

        expect(db.name).to(equal(type(of: self).testDatabase))

        // error code 59: CommandNotFound
        expect(try db.runCommand(["asdfsadf": .objectId(ObjectId())]))
            .to(throwError(ServerError.commandError(
                code: 59,
                codeName: "CommandNotFound",
                message: "",
                errorLabels: nil
            )))
    }

    func testDropDatabase() throws {
        let encoder = BSONEncoder()
        let center = NotificationCenter.default

        let client = try MongoClient.makeTestClient(options: ClientOptions(commandMonitoring: true))
        var db = client.db(type(of: self).testDatabase)

        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        var expectedWriteConcerns: [WriteConcern] = [
            try WriteConcern(journal: true, w: .number(1)),
            try WriteConcern(journal: true, w: .number(1), wtimeoutMS: 123)
        ]
        var eventsSeen = 0
        let observer = center.addObserver(forName: nil, object: nil, queue: nil) { notif in
            guard let event = notif.userInfo?["event"] as? CommandStartedEvent else {
                return
            }

            expect(event.command["dropDatabase"]).toNot(beNil())
            let expectedWriteConcern = try? encoder.encode(expectedWriteConcerns[eventsSeen])
            expect(event.command["writeConcern"]?.documentValue).to(sortedEqual(expectedWriteConcern))
            eventsSeen += 1
        }

        defer { center.removeObserver(observer) }

        for wc in expectedWriteConcerns {
            expect(try db.drop(options: DropDatabaseOptions(writeConcern: wc))).toNot(throwError())
        }
        expect(eventsSeen).to(equal(expectedWriteConcerns.count))
    }

    func testCreateCollection() throws {
        // TODO: SWIFT-539: unskip
        if MongoSwiftTestCase.ssl && MongoSwiftTestCase.isMacOS {
            print("Skipping test, fails with SSL, see CDRIVER-3318")
            return
        }

        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)

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
            writeConcern: try WriteConcern(w: .majority)
        )
        expect(try db.createCollection("foo", options: fooOptions)).toNot(throwError())

        // test view options
        let viewOptions = CreateCollectionOptions(
            pipeline: [["$project": ["a": 1]]],
            viewOn: "foo"
        )

        expect(try db.createCollection("fooView", options: viewOptions)).toNot(throwError())

        var collectionInfo = try Array(db.listCollections())
        collectionInfo.sort { $0.name < $1.name }

        expect(collectionInfo).to(haveCount(3))

        let fooInfo = CollectionSpecificationInfo(readOnly: false, uuid: UUID())
        let fooIndex = IndexModel(keys: ["_id": 1] as Document, options: IndexOptions(name: "_id_"))
        let expectedFoo = CollectionSpecification(
            name: "foo",
            type: .collection,
            options: fooOptions,
            info: fooInfo,
            idIndex: fooIndex
        )
        expect(collectionInfo[0]).to(equal(expectedFoo))

        let viewInfo = CollectionSpecificationInfo(readOnly: true, uuid: nil)
        let expectedView = CollectionSpecification(
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
        let client = try MongoClient.makeTestClient(options: ClientOptions(commandMonitoring: true))
        let db = client.db(type(of: self).testDatabase)
        try db.drop()

        let cappedOptions = CreateCollectionOptions(capped: true, max: 1000, size: 10240)
        let uncappedOptions = CreateCollectionOptions(capped: false)

        _ = try db.createCollection("capped", options: cappedOptions)
        _ = try db.createCollection("uncapped", options: uncappedOptions)
        try db.collection("capped").insertOne(["a": 1])
        try db.collection("uncapped").insertOne(["b": 2])

        let listNamesEvent = try captureCommandEvents(
            from: client,
            eventTypes: [.commandStarted],
            commandNames: ["listCollections"]
        ) {
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
        expect(listNamesEvent).to(haveCount(4))

        // Check nameOnly flag passed to server for respective listCollection calls.
        expect((listNamesEvent[0] as? CommandStartedEvent)?.command["nameOnly"]).to(equal(true))
        expect((listNamesEvent[1] as? CommandStartedEvent)?.command["nameOnly"]).to(equal(true))
        expect((listNamesEvent[2] as? CommandStartedEvent)?.command["nameOnly"]).to(equal(false))
        expect((listNamesEvent[3] as? CommandStartedEvent)?.command["nameOnly"]).to(equal(false))
    }
}

extension CreateCollectionOptions: Equatable {
    // This omits the coding strategy properties (they're not sent to/stored on the server so would not be
    // round-tripped), along with `writeConcern`, since that is used only for the "create" command itself
    // and is not a property of the collection.
    public static func == (lhs: CreateCollectionOptions, rhs: CreateCollectionOptions) -> Bool {
        return rhs.capped == lhs.capped &&
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
        return lhs.name == rhs.name &&
            lhs.type == rhs.type &&
            lhs.options == rhs.options &&
            lhs.info.readOnly == rhs.info.readOnly &&
            lhs.idIndex?.options?.name == rhs.idIndex?.options?.name
    }
}
