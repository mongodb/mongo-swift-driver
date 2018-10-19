@testable import MongoSwift
import Nimble
import XCTest

var _client: MongoClient?

final class MongoCollectionTests: XCTestCase {
    static var allTests: [(String, (MongoCollectionTests) -> () throws -> Void)] {
        return [
            ("testCount", testCount),
            ("testInsertOne", testInsertOne),
            ("testInsertOneWithUnacknowledgedWriteConcern", testInsertOneWithUnacknowledgedWriteConcern),
            ("testAggregate", testAggregate),
            ("testDrop", testDrop),
            ("testInsertMany", testInsertMany),
            ("testInsertManyWithEmptyValues", testInsertManyWithEmptyValues),
            ("testInsertManyWithUnacknowledgedWriteConcern", testInsertManyWithUnacknowledgedWriteConcern),
            ("testFind", testFind),
            ("testDeleteOne", testDeleteOne),
            ("testDeleteOneWithUnacknowledgedWriteConcern", testDeleteOneWithUnacknowledgedWriteConcern),
            ("testDeleteMany", testDeleteMany),
            ("testDeleteManyWithUnacknowledgedWriteConcern", testDeleteManyWithUnacknowledgedWriteConcern),
            ("testReplaceOne", testReplaceOne),
            ("testReplaceOneWithUnacknowledgedWriteConcern", testReplaceOneWithUnacknowledgedWriteConcern),
            ("testUpdateOne", testUpdateOne),
            ("testUpdateOneWithUnacknowledgedWriteConcern", testUpdateOneWithUnacknowledgedWriteConcern),
            ("testUpdateMany", testUpdateMany),
            ("testUpdateManyWithUnacknowledgedWriteConcern", testUpdateManyWithUnacknowledgedWriteConcern),
            ("testDistinct", testDistinct),
            ("testCreateIndexFromModel", testCreateIndexFromModel),
            ("testCreateIndexesFromModels", testCreateIndexesFromModels),
            ("testCreateIndexFromKeys", testCreateIndexFromKeys),
            ("testDropIndexByName", testDropIndexByName),
            ("testDropIndexByModel", testDropIndexByModel),
            ("testDropIndexByKeys", testDropIndexByKeys),
            ("testDropAllIndexes", testDropAllIndexes),
            ("testListIndexes", testListIndexes),
            ("testGetName", testGetName),
            ("testFindOneAndDelete", testFindOneAndDelete),
            ("testFindOneAndReplace", testFindOneAndReplace),
            ("testFindOneAndUpdate", testFindOneAndUpdate)
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

    func testInsertOneWithUnacknowledgedWriteConcern() throws {
        let options = InsertOneOptions(writeConcern: try WriteConcern(w: .number(0)))
        let insertOneResult = try self.coll.insertOne(["x": 1], options: options)
        expect(insertOneResult).to(beNil())
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

    func testInsertManyWithEmptyValues() {
        expect(try self.coll.insertMany([])).to(throwError(MongoError.invalidArgument(message: "")))
    }

    func testInsertManyWithUnacknowledgedWriteConcern() throws {
        let options = InsertManyOptions(writeConcern: try WriteConcern(w: .number(0)))
        let insertManyResult = try self.coll.insertMany([["x": 1], ["x": 2]], options: options)
        expect(insertManyResult).to(beNil())
    }

    func testFind() throws {
        let findResult = try coll.find(["cat": "cat"])
        expect(findResult.next()).to(equal(["_id": 2, "cat": "cat"]))
        expect(findResult.next()).to(beNil())
    }

    func testDeleteOne() throws {
        expect(try self.coll.deleteOne(["cat": "cat"])?.deletedCount).to(equal(1))
    }

    func testDeleteOneWithUnacknowledgedWriteConcern() throws {
        let options = DeleteOptions(writeConcern: try WriteConcern(w: .number(0)))
        let deleteOneResult = try self.coll.deleteOne(["cat": "cat"], options: options)
        expect(deleteOneResult).to(beNil())
    }

    func testDeleteMany() throws {
        expect(try self.coll.deleteMany([:])?.deletedCount).to(equal(2))
    }

    func testDeleteManyWithUnacknowledgedWriteConcern() throws {
        let options = DeleteOptions(writeConcern: try WriteConcern(w: .number(0)))
        let deleteManyResult = try self.coll.deleteMany([:], options: options)
        expect(deleteManyResult).to(beNil())
    }

    func testReplaceOne() throws {
        let replaceOneResult = try coll.replaceOne(filter: ["_id": 1], replacement: ["apple": "banana"])
        expect(replaceOneResult?.matchedCount).to(equal(1))
        expect(replaceOneResult?.modifiedCount).to(equal(1))
    }

    func testReplaceOneWithUnacknowledgedWriteConcern() throws {
        let options = ReplaceOptions(writeConcern: try WriteConcern(w: .number(0)))
        let replaceOneResult = try coll.replaceOne(
            filter: ["_id": 1], replacement: ["apple": "banana"], options: options)
        expect(replaceOneResult).to(beNil())
    }

    func testUpdateOne() throws {
        let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document])
        expect(updateOneResult?.matchedCount).to(equal(1))
        expect(updateOneResult?.modifiedCount).to(equal(1))
    }

    func testUpdateOneWithUnacknowledgedWriteConcern() throws {
        let options = UpdateOptions(writeConcern: try WriteConcern(w: .number(0)))
        let updateOneResult = try coll.updateOne(
            filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document], options: options)
        expect(updateOneResult).to(beNil())
    }

    func testUpdateMany() throws {
        let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document])
        expect(updateManyResult?.matchedCount).to(equal(2))
        expect(updateManyResult?.modifiedCount).to(equal(2))
    }

    func testUpdateManyWithUnacknowledgedWriteConcern() throws {
        let options = UpdateOptions(writeConcern: try WriteConcern(w: .number(0)))
        let updateManyResult = try coll.updateMany(
            filter: [:], update: ["$set": ["apple": "pear"] as Document], options: options)
        expect(updateManyResult).to(beNil())
    }

    func testDistinct() throws {
        let distinct1 = try coll.distinct(fieldName: "cat", filter: [:])
        expect((distinct1 as? [String])?.sorted()).to(equal(["cat", "dog"]))
        // nonexistent field
        expect(try self.coll.distinct(fieldName: "abc", filter: [:])).to(beEmpty())

        // test a null distinct value
        try coll.insertOne(["cat": nil])
        let distinct2 = try coll.distinct(fieldName: "cat", filter: [:])
        expect(distinct2).to(haveCount(3))
        expect(distinct2).to(containElementSatisfying({ $0 == nil }))
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
        while let _ = try findResult1.nextOrError() { }

        let findResult2 = try coll.find(["cat": "cat"])
        for _ in findResult2 { }
        expect(findResult2.error).to(beNil())
    }

    struct Basic: Codable, Equatable {
        let x: Int
        let y: String

        static func == (lhs: Basic, rhs: Basic) -> Bool {
            return lhs.x == rhs.x && lhs.y == rhs.y
        }
    }

    func testCodableCollection() throws {
        let client = try MongoClient()
        let db = try client.db("codable")
        defer { try? db.drop() }
        let coll1 = try db.createCollection("coll1", withType: Basic.self)

        let b1 = Basic(x: 1, y: "hi")
        let b2 = Basic(x: 2, y: "hello")
        let b3 = Basic(x: 3, y: "blah")
        let b4 = Basic(x: 4, y: "hi")
        let b5 = Basic(x: 5, y: "abc")

        try coll1.insertOne(b1)
        try coll1.insertMany([b2, b3])
        try coll1.replaceOne(filter: ["x": 2], replacement: b4)
        expect(try coll1.count()).to(equal(3))

        for doc in try coll1.find() {
            expect(doc).to(beAnInstanceOf(Basic.self))
        }

        // find one and replace w/ collection type replacement
        expect(try coll1.findOneAndReplace(filter: ["x": 1], replacement: b5)).to(equal(b1))

        // test successfully decode to collection type
        expect(try coll1.findOneAndUpdate(filter: ["x": 3], update: ["$set": ["x": 6] as Document])).to(equal(b3))
        expect(try coll1.findOneAndDelete(["x": 4])).to(equal(b4))
    }

    func testEncodeCursorType() throws {
        let encoder = BSONEncoder()

        let nonTailable = FindOptions(cursorType: .nonTailable)
        expect(try encoder.encode(nonTailable)).to(equal(["awaitData": false, "tailable": false]))

        let tailable = FindOptions(cursorType: .tailable)
        expect(try encoder.encode(tailable)).to(equal(["awaitData": false, "tailable": true ]))

        let tailableAwait = FindOptions(cursorType: .tailableAwait)
        expect(try encoder.encode(tailableAwait)).to(equal(["awaitData": true, "tailable": true ]))
    }

    func testEncodeHint() throws {
        let encoder = BSONEncoder()

        let stringHint = AggregateOptions(hint: .indexName("hi"))
        expect(try encoder.encode(stringHint)).to(equal(["hint": "hi"]))

        let docHint = AggregateOptions(hint: .indexSpec(["hi": 1]))
        expect(try encoder.encode(docHint)).to(equal(["hint": ["hi": 1] as Document]))
    }

    func testFindOneAndDelete() throws {
        // test using maxTimeMS
        let opts1 = FindOneAndDeleteOptions(maxTimeMS: 100)
        let result1 = try self.coll.findOneAndDelete(["cat": "cat"], options: opts1)
        expect(result1).to(equal(self.doc2))
        expect(try self.coll.count()).to(equal(1))

        // test using a write concern
        let opts2 = FindOneAndDeleteOptions(writeConcern: try WriteConcern(w: .majority))
        let result2 = try self.coll.findOneAndDelete([:], options: opts2)
        expect(result2).to(equal(self.doc1))
        expect(try self.coll.count()).to(equal(0))

        // test invalid maxTimeMS throws error
        let invalidOpts1 = FindOneAndDeleteOptions(maxTimeMS: 0)
        let invalidOpts2 = FindOneAndDeleteOptions(maxTimeMS: -1)
        expect(try self.coll.findOneAndDelete([:], options: invalidOpts1)).to(throwError())
        expect(try self.coll.findOneAndDelete([:], options: invalidOpts2)).to(throwError())
    }

    func testFindOneAndReplace() throws {
        // test using maxTimeMS
        let opts1 = FindOneAndReplaceOptions(maxTimeMS: 100)
        let result1 = try self.coll.findOneAndReplace(filter: ["cat": "cat"], replacement: ["cat": "blah"], options: opts1)
        expect(result1).to(equal(self.doc2))
        expect(try self.coll.count()).to(equal(2))

        // test using bypassDocumentValidation
        let opts2 = FindOneAndReplaceOptions(bypassDocumentValidation: true)
        let result2 = try self.coll.findOneAndReplace(filter: ["cat": "dog"], replacement: ["cat": "hi"], options: opts2)
        expect(result2).to(equal(self.doc1))
        expect(try self.coll.count()).to(equal(2))

        // test using a write concern
        let opts3 = FindOneAndReplaceOptions(writeConcern: try WriteConcern(w: .majority))
        let result3 = try self.coll.findOneAndReplace(filter: ["cat": "blah"], replacement: ["cat": "cat"], options: opts3)
        expect(result3).to(equal(["_id": 2, "cat": "blah"]))
        expect(try self.coll.count()).to(equal(2))

        // test invalid maxTimeMS throws error
        let invalidOpts1 = FindOneAndReplaceOptions(maxTimeMS: 0)
        let invalidOpts2 = FindOneAndReplaceOptions(maxTimeMS: -1)
        expect(try self.coll.findOneAndReplace(filter: [:], replacement: [:], options: invalidOpts1)).to(throwError())
        expect(try self.coll.findOneAndReplace(filter: [:], replacement: [:], options: invalidOpts2)).to(throwError())
    }

    func testFindOneAndUpdate() throws {
        // test using maxTimeMS
        let opts1 = FindOneAndUpdateOptions(maxTimeMS: 100)
        let result1 = try self.coll.findOneAndUpdate(filter: ["cat": "cat"], update: ["$set": ["cat": "blah"] as Document], options: opts1)
        expect(result1).to(equal(self.doc2))
        expect(try self.coll.count()).to(equal(2))

        // test using bypassDocumentValidation
        let opts2 = FindOneAndUpdateOptions(bypassDocumentValidation: true)
        let result2 = try self.coll.findOneAndUpdate(filter: ["cat": "dog"], update: ["$set": ["cat": "hi"] as Document], options: opts2)
        expect(result2).to(equal(self.doc1))
        expect(try self.coll.count()).to(equal(2))

        // test using a write concern
        let opts3 = FindOneAndUpdateOptions(writeConcern: try WriteConcern(w: .majority))
        let result3 = try self.coll.findOneAndUpdate(filter: ["cat": "blah"], update: ["$set": ["cat": "cat"] as Document], options: opts3)
        expect(result3).to(equal(["_id": 2, "cat": "blah"]))
        expect(try self.coll.count()).to(equal(2))

        // test invalid maxTimeMS throws error
        let invalidOpts1 = FindOneAndUpdateOptions(maxTimeMS: 0)
        let invalidOpts2 = FindOneAndUpdateOptions(maxTimeMS: -1)
        expect(try self.coll.findOneAndUpdate(filter: [:], update: [:], options: invalidOpts1)).to(throwError())
        expect(try self.coll.findOneAndUpdate(filter: [:], update: [:], options: invalidOpts2)).to(throwError())
    }

    func testNullIds() throws {
        let result1 = try self.coll.insertOne(["_id": nil, "hi": "hello"])
        expect(result1).toNot(beNil())
        expect(result1?.insertedId).to(beNil())

        try self.coll.deleteOne(["_id": nil])

        let result2 = try self.coll.insertMany([["_id": nil], ["_id": 20]])
        expect(result2).toNot(beNil())
        expect(result2?.insertedIds[0]!).to(beNil())
        expect(result2?.insertedIds[1] as? Int).to(equal(20))
    }
}
