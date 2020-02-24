import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

private var _client: MongoClient?

final class MongoCollection_IndexTests: MongoSwiftTestCase {
    var collName: String = ""
    var coll: MongoCollection<Document>!
    let doc1: Document = ["_id": 1, "cat": "dog"]
    let doc2: Document = ["_id": 2, "cat": "cat"]

    /// Set up the entire suite - run once before all tests
    override class func setUp() {
        super.setUp()
        do {
            _client = try MongoClient.makeTestClient()
        } catch {
            print("Setup failed: \(error)")
        }
    }

    /// Set up a single test - run before each testX function
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
        self.collName = self.getCollectionName()

        do {
            guard let client = _client else {
                XCTFail("Invalid client")
                return
            }
            self.coll = try client.db(type(of: self).testDatabase).createCollection(self.collName)
            try self.coll.insertMany([doc1, doc2])
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }

    /// Teardown a single test - run after each testX function
    override func tearDown() {
        super.tearDown()
        do {
            if self.coll != nil { try self.coll.drop() }
        } catch {
            XCTFail("Dropping test collection \(type(of: self).testDatabase).\(self.collName) failed: \(error)")
        }
    }

    /// Teardown the entire suite - run after all tests complete
    override class func tearDown() {
        super.tearDown()
        do {
            guard let client = _client else {
                print("Invalid client")
                return
            }
            try client.db(self.testDatabase).drop()
        } catch {
            print("Dropping test database \(self.testDatabase) failed: \(error)")
        }
    }

    func testCreateIndexFromModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        let indexes = try coll.listIndexes()
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get().options?.name).to(equal("cat_1"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testIndexOptions() throws {
        let options = IndexOptions(
            background: true,
            bits: 32,
            bucketSize: 10,
            collation: ["locale": "fr"],
            defaultLanguage: "english",
            languageOverride: "cat",
            max: 30,
            min: 0,
            name: "testOptions",
            sparse: false,
            sphereIndexVersion: 2,
            storageEngine: ["wiredTiger": ["configString": "access_pattern_hint=random"]],
            textIndexVersion: 2,
            unique: true,
            version: 2,
            weights: ["cat": 0.5, "_id": 0.5]
        )

        let model = IndexModel(keys: ["cat": 1, "_id": -1], options: options)
        expect(try self.coll.createIndex(model)).to(equal("testOptions"))

        let ttlOptions = IndexOptions(expireAfterSeconds: 100, name: "ttl")
        let ttlModel = IndexModel(keys: ["cat": 1], options: ttlOptions)
        expect(try self.coll.createIndex(ttlModel)).to(equal("ttl"))

        var indexOptions: [IndexOptions] = try self.coll.listIndexes().all().map { $0.options ?? IndexOptions() }
        indexOptions.sort { $0.name! < $1.name! }
        expect(indexOptions).to(haveCount(3))

        // _id index
        expect(indexOptions[0]).to(equal(IndexOptions(name: "_id_", version: 2)))

        // testOptions index
        var expectedTestOptions = options
        expectedTestOptions.name = "testOptions"
        expect(indexOptions[1]).to(equal(expectedTestOptions))

        // ttl index
        var expectedTtlOptions = ttlOptions
        expectedTtlOptions.version = 2
        expect(indexOptions[2]).to(equal(expectedTtlOptions))
    }

    func testCreateIndexesFromModels() throws {
        let model1 = IndexModel(keys: ["cat": 1])
        let model2 = IndexModel(keys: ["cat": -1])
        expect(try self.coll.createIndexes([model1, model2])).to(equal(["cat_1", "cat_-1"]))
        let indexes = try coll.listIndexes()
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get().options?.name).to(equal("cat_1"))
        expect(try indexes.next()?.get().options?.name).to(equal("cat_-1"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testCreateIndexFromKeys() throws {
        expect(try self.coll.createIndex(["cat": 1])).to(equal("cat_1"))

        let indexOptions = IndexOptions(name: "blah", unique: true)
        let model = IndexModel(keys: ["cat": -1], options: indexOptions)
        expect(try self.coll.createIndex(model)).to(equal("blah"))

        let indexes = try coll.listIndexes()
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get().options?.name).to(equal("cat_1"))

        let thirdIndex = try indexes.next()?.get()
        expect(thirdIndex?.options?.name).to(equal("blah"))
        expect(thirdIndex?.options?.unique).to(equal(true))

        expect(indexes.next()).to(beNil())
    }

    func testDropIndexByName() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        expect(try self.coll.dropIndex("cat_1")).toNot(throwError())

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testDropIndexByModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))

        expect(try self.coll.dropIndex(model)).toNot(throwError())

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes).toNot(beNil())
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testDropIndexByKeys() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))

        expect(try self.coll.dropIndex(["cat": 1])).toNot(throwError())

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes).toNot(beNil())
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testDropAllIndexes() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))

        expect(try self.coll.dropIndexes()).toNot(throwError())

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
        expect(try indexes.next()?.get()).to(beNil())
    }

    func testListIndexNames() throws {
        let model1 = IndexModel(keys: ["cat": 1])
        let model2 = IndexModel(keys: ["cat": -1], options: IndexOptions(name: "neg cat"))
        expect(try self.coll.createIndexes([model1, model2])).to(equal(["cat_1", "neg cat"]))
        let indexNames = try coll.listIndexNames()

        expect(indexNames.count).to(equal(3))
        expect(indexNames[0]).to(equal("_id_"))
        expect(indexNames[1]).to(equal("cat_1"))
        expect(indexNames[2]).to(equal("neg cat"))
    }

    func testCreateDropIndexByModelWithMaxTimeMS() throws {
        let maxTimeMS: Int64 = 1000

        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let db = client.db(type(of: self).testDatabase)
        let collection = db.collection("collection")
        try collection.insertOne(["test": "blahblah"])

        try monitor.captureEvents {
            let model = IndexModel(keys: ["cat": 1])
            let wc = try WriteConcern(w: .number(1))
            let createIndexOpts = CreateIndexOptions(maxTimeMS: maxTimeMS, writeConcern: wc)
            expect(try collection.createIndex(model, options: createIndexOpts)).to(equal("cat_1"))

            let dropIndexOpts = DropIndexOptions(maxTimeMS: maxTimeMS, writeConcern: wc)
            expect(try collection.dropIndex(model, options: dropIndexOpts)).toNot(throwError())

            // now there should only be _id_ left
            let indexes = try coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(try indexes.next()?.get().options?.name).to(equal("_id_"))
            expect(try indexes.next()?.get()).to(beNil())
        }

        // test that maxTimeMS is an accepted option for createIndex and dropIndex
        let receivedEvents = monitor.commandStartedEvents()
        expect(receivedEvents.count).to(equal(2))
        expect(receivedEvents[0].command["createIndexes"]).toNot(beNil())
        expect(receivedEvents[0].command["maxTimeMS"]).toNot(beNil())
        expect(receivedEvents[0].command["maxTimeMS"]).to(equal(.int64(maxTimeMS)))
        expect(receivedEvents[1].command["dropIndexes"]).toNot(beNil())
        expect(receivedEvents[1].command["maxTimeMS"]).toNot(beNil())
        expect(receivedEvents[1].command["maxTimeMS"]).to(equal(.int64(maxTimeMS)))
    }
}

extension IndexOptions: Equatable {
    public static func == (lhs: IndexOptions, rhs: IndexOptions) -> Bool {
        return lhs.background == rhs.background &&
            lhs.expireAfterSeconds == rhs.expireAfterSeconds &&
            lhs.name == rhs.name &&
            lhs.sparse == rhs.sparse &&
            lhs.storageEngine == rhs.storageEngine &&
            lhs.unique == rhs.unique &&
            lhs.version == rhs.version &&
            lhs.defaultLanguage == rhs.defaultLanguage &&
            lhs.languageOverride == rhs.languageOverride &&
            lhs.textIndexVersion == rhs.textIndexVersion &&
            lhs.weights == rhs.weights &&
            lhs.sphereIndexVersion == rhs.sphereIndexVersion &&
            lhs.bits == rhs.bits &&
            lhs.max == rhs.max &&
            lhs.min == rhs.min &&
            lhs.bucketSize == rhs.bucketSize &&
            lhs.partialFilterExpression == rhs.partialFilterExpression &&
            lhs.collation?["locale"] == rhs.collation?["locale"]
        // ^ server adds a bunch of extra fields and a version number
        // to collations. rather than deal with those, just verify the
        // locale matches.
    }
}
