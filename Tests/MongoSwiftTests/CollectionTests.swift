@testable import MongoSwift
import Quick
import Nimble

class CollectionTests: QuickSpec {

    override func setUp() {
         continueAfterFailure = false
    }

    override func spec() {
        let doc1: Document = ["_id": 1, "cat": "dog"]
        let doc2: Document = ["_id": 2, "cat": "cat"]

        var client: MongoClient?
        var coll: MongoCollection!

        beforeSuite {
            expect { client = try MongoClient() }.toNot(throwError())
        }

        afterSuite {
            expect(client).toNot(beNil())
            expect { try client!.db("collectionTest").drop() }.toNot(throwError())
        }

        beforeEach {
            // if the last test failed then we need to drop coll here
            if coll != nil { expect { try coll.drop() }.toNot(throwError()) }
            expect(client).toNot(beNil())
            expect { coll = try client!.db("collectionTest").createCollection("coll1") }.toNot(throwError())
            expect(coll).toNot(beNil())
            expect { try coll.insertMany([doc1, doc2]) }.toNot(throwError())
        }

        afterEach {
            expect(coll).toNot(beNil())
            expect { try coll.drop() }.toNot(throwError())
            coll = nil
        }

        it("Should correctly count documents in collection") {
            expect { try coll.count() }.to(equal(2))
            let options = CountOptions(limit: 5, maxTimeMS: 1000, skip: 5)
            expect {try coll.count(options: options)}.to(equal(0))
        }

        it("Should correctly insert a single document") {
            expect { try coll.deleteMany([:]) }.toNot(beNil())
            expect { try coll.insertOne(doc1)?.insertedId as? Int }.to(equal(1))
            expect { try coll.insertOne(doc2)?.insertedId as? Int }.to(equal(2))
            expect { try coll.count() }.to(equal(2))

            // try inserting a document without an ID to verify one is generated and returned
            expect { try coll.insertOne(["x": 1])?.insertedId }.toNot(beNil())
        }

        it("Should correctly aggregate data") {
            expect {
                Array(try coll.aggregate([["$project": ["_id": 0, "cat": 1] as Document]]))}
                .to(equal([["cat": "dog"], ["cat": "cat"]] as [Document]))
        }

        it("Should correctly drop a collection") {
            expect { try coll.drop() }.toNot(throwError())
            // insert something so we don't error when trying to drop again in teardown
            expect { try coll.insertOne(doc1) }.toNot(throwError())
        }

        it("Should correctly insert multiple documents at once") {
            expect { try coll.count() }.to(equal(2))
            // try inserting a mix of documents with and without IDs to verify they are generated
            let docNoId1: Document = ["x": 1]
            let docNoId2: Document = ["x": 2]
            let docId1: Document = ["_id": 10, "x": 8]
            let docId2: Document = ["_id": 11, "x": 9]

            let res = try? coll.insertMany([docNoId1, docNoId2, docId1, docId2])
            expect(res).toNot(beNil())

            // the inserted IDs should either be the ones we set,
            // or newly created ObjectIds
            for (_, v) in res!!.insertedIds {
                if let val = v as? Int {
                    expect([10, 11]).to(contain(val))
                } else {
                    expect(v).to(beAnInstanceOf(ObjectId.self))
                }
            }
        }

        it("Should correctly find all documents with no filter") {
            let findResult = try? coll.find(["cat": "cat"])
            expect(findResult).toNot(beNil())
            expect(findResult!.next()).to(equal(["_id": 2, "cat": "cat"]))
            expect(findResult!.next()).to(beNil())
        }

        it("Should correctly delete one document") {
            expect { try coll.deleteOne(["cat": "cat"])?.deletedCount }.to(equal(1))
        }

        it("Should correctly delete many documents") {
            expect { try coll.deleteMany([:])?.deletedCount }.to(equal(2))
        }

        it("Should correctly replace one document") {
            let replaceOneResult = try? coll.replaceOne(filter: ["_id": 1], replacement: ["apple": "banana"])
            expect(replaceOneResult).toNot(beNil())
            expect(replaceOneResult!!.matchedCount).to(equal(1))
            expect(replaceOneResult!!.modifiedCount).to(equal(1))
        }

        it("Should correctly update one document") {
            let updateOneResult = try? coll.updateOne(
                filter: ["_id": 2], update: ["$set": ["apple": "banana"] as Document])
            expect(updateOneResult).toNot(beNil())
            expect(updateOneResult!!.matchedCount).to(equal(1))
            expect(updateOneResult!!.modifiedCount).to(equal(1))
        }

        it("Should correctly update many documents") {
            let updateManyResult = try? coll.updateMany(
                filter: [:], update: ["$set": ["apple": "pear"] as Document])
            expect(updateManyResult).toNot(beNil())
            expect(updateManyResult!!.matchedCount).to(equal(2))
            expect(updateManyResult!!.modifiedCount).to(equal(2))
        }

        it("Should correctly return distinct values") {
            let distinct = try? coll.distinct(fieldName: "cat", filter: [:])
            expect(distinct).toNot(beNil())
            expect((distinct!.next()?["values"] as? [String])!.sorted()).to(equal(["cat", "dog"]))
            expect(distinct!.next()).to(beNil())
        }

        it("Should correctly create an index from a model") {
            let model = IndexModel(keys: ["cat": 1])
            expect { try coll.createIndex(model) }.to(equal("cat_1"))
            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()?["name"] as? String).to(equal("cat_1"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly create multiple indexes from models") {
            let model1 = IndexModel(keys: ["cat": 1])
            let model2 = IndexModel(keys: ["cat": -1])
            expect { try coll.createIndexes([model1, model2]) }.to(equal(["cat_1", "cat_-1"]))
            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()?["name"] as? String).to(equal("cat_1"))
            expect(indexes!.next()?["name"] as? String).to(equal("cat_-1"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly create an index from keys") {
            expect { try coll.createIndex(["cat": 1]) }.to(equal("cat_1"))

            let indexOptions = IndexOptions(name: "blah", unique: true)
            let model = IndexModel(keys: ["cat": -1], options: indexOptions)
            expect { try coll.createIndex(model) }.to(equal("blah"))

            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()?["name"] as? String).to(equal("cat_1"))

            let thirdIndex = indexes!.next()
            expect(thirdIndex).toNot(beNil())

            expect(thirdIndex!["name"] as? String).to(equal("blah"))
            expect(thirdIndex?["unique"] as? Bool).to(beTrue())

            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly drop an index by name") {
            let model = IndexModel(keys: ["cat": 1])
            expect { try coll.createIndex(model) }.to(equal("cat_1"))
            expect { try coll.dropIndex("cat_1") }.toNot(throwError())

            // now there should only be _id_ left
            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly drop an index by model") {
            let model = IndexModel(keys: ["cat": 1])
            expect { try coll.createIndex(model) }.to(equal("cat_1"))
            expect { try coll.dropIndex(model)["ok"] as? Double }.to(equal(1.0))

            // now there should only be _id_ left
            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly drop an index by keys") {
            let model = IndexModel(keys: ["cat": 1])
            expect { try coll.createIndex(model) }.to(equal("cat_1"))
            expect { try coll.dropIndex(["cat": 1])["ok"] as? Double }.to(equal(1.0))

            // now there should only be _id_ left
            let indexes = try? coll.listIndexes()
            expect(indexes).toNot(beNil())
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly drop all indexes") {
            let model = IndexModel(keys: ["cat": 1])
            expect { try coll.createIndex(model) }.to(equal("cat_1"))
            expect { try coll.dropIndexes()["ok"] as? Double }.to(equal(1.0))

            // now there should only be _id_ left
            let indexes = try? coll.listIndexes()
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()).to(beNil())
        }

        it("Should correctly list indexes") {
            let indexes = try? coll.listIndexes()
            // New collection, so expect just the _id_ index to exist. 
            expect(indexes!.next()?["name"] as? String).to(equal("_id_"))
            expect(indexes!.next()).to(beNil())
        }
    }
}
