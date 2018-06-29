@testable import MongoSwift
import XCTest
import Nimble

var _client: MongoClient?

final class CollectionTests: XCTestCase {
    static var allTests: [(String, (CollectionTests) -> () throws -> Void)] {
        return [
            ("testCount", testCount),
            ("testInsertOne", testInsertOne),
            ("testAggregate", testAggregate),
            ("testDrop", testDrop),
            ("testInsertMany", testInsertMany),
            ("testFind", testFind),
            ("testDeleteOne", testDeleteOne),
            ("testDeleteMany", testDeleteMany),
            ("testReplaceOne", testReplaceOne),
            ("testUpdateOne", testUpdateOne),
            ("testUpdateMany", testUpdateMany),
            ("testDistinct", testDistinct),
            ("testCreateIndexFromModel", testCreateIndexFromModel),
            ("testCreateIndexesFromModels", testCreateIndexesFromModels),
            ("testCreateIndexFromKeys", testCreateIndexFromKeys),
            ("testDropIndexByName", testDropIndexByName),
            ("testDropIndexByModel", testDropIndexByModel),
            ("testDropIndexByKeys", testDropIndexByKeys),
            ("testDropAllIndexes", testDropAllIndexes),
            ("testListIndexes", testListIndexes),
            ("testGetName", testGetName)
        ]
    }

    var coll: MongoCollection<Document>!
    let doc1: Document = ["_id": 1, "cat": "dog"]
    let doc2: Document = ["_id": 2, "cat": "cat"]

    /// Set up the entire suite - run once before all tests
    override class func setUp() {
        super.setUp()
        do {
            _client = try MongoClient()
        } catch {
            print("Setup failed: \(error)")
        }
    }

    /// Set up a single test - run before each testX function
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
        do {
            guard let client = _client else {
                XCTFail("Invalid client")
                return
            }
            coll = try client.db("collectionTest").createCollection("coll1")
            try coll.insertMany([doc1, doc2])
        } catch {
            XCTFail("Setup failed: \(error)")
        }
    }

    /// Teardown a single test - run after each testX function
    override func tearDown() {
        super.tearDown()
        do {
            if coll != nil { try coll.drop() }
        } catch {
            XCTFail("Dropping test collection collectionTest.coll1 failed: \(error)")
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
            try client.db("collectionTest").drop()
        } catch {
            print("Dropping test database collectionTest failed: \(error)")
        }
    }

    func testCount() throws {
        expect(try self.coll.count()).to(equal(2))
        let options = CountOptions(limit: 5, maxTimeMS: 1000, skip: 5)
        expect(try self.coll.count(options: options)).to(equal(0))
    }

    func testInsertOne() throws {
        expect(try self.coll.deleteMany([:])).toNot(beNil())
        expect(try self.coll.insertOne(self.doc1)?.insertedId as? Int).to(equal(1))
        expect(try self.coll.insertOne(self.doc2)?.insertedId as? Int).to(equal(2))
        expect(try self.coll.count()).to(equal(2))

        // try inserting a document without an ID to verify one is generated and returned
        expect(try self.coll.insertOne(["x": 1])?.insertedId).toNot(beNil())
    }

    func testAggregate() throws {
        expect(
            Array(try self.coll.aggregate([["$project": ["_id": 0, "cat": 1] as Document]])))
            .to(equal([["cat": "dog"], ["cat": "cat"]] as [Document]))
    }

    func testDrop() throws {
        expect(try self.coll.drop()).toNot(throwError())
        // insert something so we don't error when trying to drop again in teardown
        expect(try self.coll.insertOne(self.doc1)).toNot(throwError())
    }

    func testInsertMany() throws {
        expect(try self.coll.count()).to(equal(2))
        // try inserting a mix of documents with and without IDs to verify they are generated
        let docNoId1: Document = ["x": 1]
        let docNoId2: Document = ["x": 2]
        let docId1: Document = ["_id": 10, "x": 8]
        let docId2: Document = ["_id": 11, "x": 9]

        let res = try coll.insertMany([docNoId1, docNoId2, docId1, docId2])

        // the inserted IDs should either be the ones we set,
        // or newly created ObjectIds
        for (_, v) in res!.insertedIds {
            if let val = v as? Int {
                expect([10, 11]).to(contain(val))
            } else {
                expect(v).to(beAnInstanceOf(ObjectId.self))
            }
        }
    }

    func testFind() throws {
        let findResult = try coll.find(["cat": "cat"])
        expect(findResult.next()).to(equal(["_id": 2, "cat": "cat"]))
        expect(findResult.next()).to(beNil())
    }

    func testDeleteOne() throws {
        expect(try self.coll.deleteOne(["cat": "cat"])?.deletedCount).to(equal(1))
    }

    func testDeleteMany() throws {
        expect(try self.coll.deleteMany([:])?.deletedCount).to(equal(2))
    }

    func testReplaceOne() throws {
        let replaceOneResult = try coll.replaceOne(filter: ["_id": 1], replacement: ["apple": "banana"])
        expect(replaceOneResult?.matchedCount).to(equal(1))
        expect(replaceOneResult?.modifiedCount).to(equal(1))
    }

    func testUpdateOne() throws {
        let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document])
        expect(updateOneResult?.matchedCount).to(equal(1))
        expect(updateOneResult?.modifiedCount).to(equal(1))
    }

    func testUpdateMany() throws {
        let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document])
        expect(updateManyResult?.matchedCount).to(equal(2))
        expect(updateManyResult?.modifiedCount).to(equal(2))
    }

    func testDistinct() throws {
        let distinct = try coll.distinct(fieldName: "cat", filter: [:])
        expect((distinct.next()?["values"] as? [String])!.sorted()).to(equal(["cat", "dog"]))
        expect(distinct.next()).to(beNil())
    }

    func testCreateIndexFromModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        let indexes = try coll.listIndexes()
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()?["name"] as? String).to(equal("cat_1"))
        expect(indexes.next()).to(beNil())
    }

    func testCreateIndexesFromModels() throws {
        let model1 = IndexModel(keys: ["cat": 1])
        let model2 = IndexModel(keys: ["cat": -1])
        expect( try self.coll.createIndexes([model1, model2]) ).to(equal(["cat_1", "cat_-1"]))
        let indexes = try coll.listIndexes()
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()?["name"] as? String).to(equal("cat_1"))
        expect(indexes.next()?["name"] as? String).to(equal("cat_-1"))
        expect(indexes.next()).to(beNil())
    }

    func testCreateIndexFromKeys() throws {
        expect(try self.coll.createIndex(["cat": 1])).to(equal("cat_1"))

        let indexOptions = IndexOptions(name: "blah", unique: true)
        let model = IndexModel(keys: ["cat": -1], options: indexOptions)
        expect(try self.coll.createIndex(model)).to(equal("blah"))

        let indexes = try coll.listIndexes()
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()?["name"] as? String).to(equal("cat_1"))

        let thirdIndex = indexes.next()
        expect(thirdIndex?["name"] as? String).to(equal("blah"))
        expect(thirdIndex?["unique"] as? Bool).to(beTrue())

        expect(indexes.next()).to(beNil())
    }

    func testDropIndexByName() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        expect(try self.coll.dropIndex("cat_1")).toNot(throwError())

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()).to(beNil())
    }

    func testDropIndexByModel() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        expect(try self.coll.dropIndex(model)["ok"] as? Double).to(equal(1.0))

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes).toNot(beNil())
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()).to(beNil())
    }

    func testDropIndexByKeys() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        expect(try self.coll.dropIndex(["cat": 1])["ok"] as? Double).to(equal(1.0))

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes).toNot(beNil())
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()).to(beNil())
    }

    func testDropAllIndexes() throws {
        let model = IndexModel(keys: ["cat": 1])
        expect(try self.coll.createIndex(model)).to(equal("cat_1"))
        expect(try self.coll.dropIndexes()["ok"] as? Double).to(equal(1.0))

        // now there should only be _id_ left
        let indexes = try coll.listIndexes()
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()).to(beNil())
    }

    func testListIndexes() throws {
        let indexes = try coll.listIndexes()
        // New collection, so expect just the _id_ index to exist. 
        expect(indexes.next()?["name"] as? String).to(equal("_id_"))
        expect(indexes.next()).to(beNil())
    }

    func testGetName() {
        expect(self.coll.name).to(equal("coll1"))
    }

    func testCursorIteration() throws {
        let findResult1 = try coll.find(["cat": "cat"])
        while let _  = try findResult1.nextOrError() { }

        let findResult2 = try coll.find(["cat": "cat"])
        for _ in findResult2 { }
        expect(findResult2.error).to(beNil())
    }

    struct Basic: Codable {
        let x: Int
        let y: String
    }

    func testCodableCollection() throws {
        let client = try MongoClient()
        let db = try client.db("codable")
        defer { try? db.drop() }
        let coll1 = try db.createCollection("coll1", withType: Basic.self)
        try coll1.insertOne(Basic(x: 1, y: "hi"))
        try coll1.insertMany([Basic(x: 2, y: "hello"), Basic(x: 3, y: "blah")])
        try coll1.replaceOne(filter: ["x": 2], replacement: Basic(x: 4, y: "hi"))
        expect(try coll1.count()).to(equal(3))

        for doc in try coll1.find() {
            expect(doc).to(beAnInstanceOf(Basic.self))
        }
    }

    func testEncodeCursorType() throws {
        let encoder = BsonEncoder()

        let nonTailable = FindOptions(cursorType: .nonTailable)
        expect(try encoder.encode(nonTailable)).to(equal(["awaitData": false, "tailable": false]))

        let tailable = FindOptions(cursorType: .tailable)
        expect(try encoder.encode(tailable)).to(equal(["awaitData": false, "tailable": true ]))

        let tailableAwait = FindOptions(cursorType: .tailableAwait)
        expect(try encoder.encode(tailableAwait)).to(equal(["awaitData": true, "tailable": true ]))
    }

    func testEncodeHint() throws {
        let encoder = BsonEncoder()

        let stringHint = AggregateOptions(hint: .indexName("hi"))
        expect(try encoder.encode(stringHint)).to(equal(["hint": "hi"]))

        let docHint = AggregateOptions(hint: .indexSpec(["hi": 1]))
        expect(try encoder.encode(docHint)).to(equal(["hint": ["hi": 1] as Document]))
    }
}
