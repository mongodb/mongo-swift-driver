import Foundation
import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

final class CrudTests: MongoSwiftTestCase {
    // Teardown at the very end of the suite by dropping the db we tested on.
    override class func tearDown() {
        super.tearDown()
        do {
            try MongoClient.makeTestClient().db(self.testDatabase).drop()
        } catch {
            print("Dropping test db \(self.testDatabase) failed: \(error)")
        }
    }

    // Run tests for .json files at the provided path
    func doTests(forSubdirectory dir: String) throws {
        let files = try retrieveSpecTestFiles(specName: "crud", subdirectory: dir, asType: CrudTestFile.self)

        let client = try MongoClient.makeTestClient()
        let db = client.db(Self.testDatabase)

        for (filename, file) in files {
            if try !client.serverVersionIsInRange(file.minServerVersion, file.maxServerVersion) {
                print("Skipping tests from file \(filename) for server version \(try client.serverVersion())")
                continue
            }

            print("\n------------\nExecuting tests from file \(dir)/\(filename)...\n")

            // For each file, execute the test cases contained in it
            for (i, test) in try file.makeTests().enumerated() {
                if type(of: test) == CountTest.self {
                    print("Skipping test for old count API, no longer supported by the driver")
                }

                print("Executing test: \(test.description)")

                // for each test case:
                // 1) create a unique collection to use
                // 2) insert the data specified by this test file
                // 3) execute the test according to the type's execute method
                // 4) verify that expected data is present
                // 5) drop the collection to clean up
                let collection = db.collection(self.getCollectionName(suffix: "\(filename)_\(i)"))
                if !file.data.isEmpty {
                    try collection.insertMany(file.data)
                }
                try test.execute(usingCollection: collection)
                try test.verifyData(testCollection: collection, db: db)
                try collection.drop()
            }
        }
        print() // for readability of results
    }

    // Run all the tests at the /read path
    func testReads() throws {
        try self.doTests(forSubdirectory: "read")
    }

    // Run all the tests at the /write path
    func testWrites() throws {
        try self.doTests(forSubdirectory: "write")
    }
}

/// A container for the data from a single .json file.
private struct CrudTestFile: Decodable {
    let data: [BSONDocument]
    let testDocs: [BSONDocument]

    func makeTests() throws -> [CrudTest] {
        try self.testDocs.map { try makeCrudTest($0) }
    }

    let minServerVersion: String?
    let maxServerVersion: String?

    enum CodingKeys: String, CodingKey {
        case data, testDocs = "tests", minServerVersion, maxServerVersion
    }
}

/// Initializes a new `CrudTest` of the appropriate subclass from a `Document`
private func makeCrudTest(_ doc: BSONDocument) throws -> CrudTest {
    let operation: BSONDocument = try doc.get("operation")
    let opName: String = try operation.get("name")
    guard let type = testTypeMap[opName] else {
        throw TestError(message: "Unknown operation name \(opName)")
    }
    return try type.init(doc)
}

// Maps operation names to the appropriate test class to use for them.
private var testTypeMap: [String: CrudTest.Type] = [
    "aggregate": AggregateTest.self,
    "bulkWrite": BulkWriteTest.self,
    "count": CountTest.self,
    "countDocuments": CountDocumentsTest.self,
    "deleteMany": DeleteTest.self,
    "deleteOne": DeleteTest.self,
    "distinct": DistinctTest.self,
    "estimatedDocumentCount": EstimatedDocumentCountTest.self,
    "find": FindTest.self,
    "findOneAndDelete": FindOneAndDeleteTest.self,
    "findOneAndUpdate": FindOneAndUpdateTest.self,
    "findOneAndReplace": FindOneAndReplaceTest.self,
    "insertMany": InsertManyTest.self,
    "insertOne": InsertOneTest.self,
    "replaceOne": ReplaceOneTest.self,
    "updateMany": UpdateTest.self,
    "updateOne": UpdateTest.self
]

/// An abstract class to represent a single test within a CrudTestFile. Subclasses must
/// implement the `execute` method themselves.
private class CrudTest {
    let description: String
    let operationName: String
    let args: BSONDocument
    let error: Bool?
    let result: BSON?
    let collection: BSONDocument?

    var arrayFilters: [BSONDocument]? { self.args["arrayFilters"]?.arrayValue?.compactMap(\.documentValue) }
    var batchSize: Int? { self.args["batchSize"]?.toInt() }
    var collation: BSONDocument? { self.args["collation"]?.documentValue }
    var sort: BSONDocument? { self.args["sort"]?.documentValue }
    var skip: Int? { self.args["skip"]?.toInt() }
    var limit: Int? { self.args["limit"]?.toInt() }
    var projection: BSONDocument? { self.args["projection"]?.documentValue }
    var returnDoc: ReturnDocument? {
        if let ret = self.args["returnDocument"]?.stringValue {
            return ret == "After" ? .after : .before
        }
        return nil
    }

    var upsert: Bool? { self.args["upsert"]?.boolValue }

    /// Initializes a new `CrudTest` from a `Document`.
    required init(_ test: BSONDocument) throws {
        self.description = try test.get("description")
        let operation: BSONDocument = try test.get("operation")
        self.operationName = try operation.get("name")
        self.args = try operation.get("arguments")
        let outcome: BSONDocument = try test.get("outcome")
        self.error = outcome["error"]?.boolValue
        self.result = outcome["result"]
        self.collection = outcome["collection"]?.documentValue
    }

    // Subclasses should implement `execute` according to the particular operation(s) they are for.
    func execute(usingCollection _: MongoCollection<BSONDocument>) throws { XCTFail("Unimplemented") }

    // If the test has a `collection` field in its `outcome`, verify that the expected
    // data is present. If there is no `collection` field, do nothing.
    func verifyData(testCollection coll: MongoCollection<BSONDocument>, db: MongoDatabase) throws {
        // only  some tests have data to verify
        guard let collection = self.collection else {
            return
        }
        // if a name is not specified, check the current collection
        var collToCheck = coll
        if let name = collection["name"]?.stringValue {
            collToCheck = db.collection(name)
        }
        expect(BSON.array(try collToCheck.find([:]).all().map { .document($0) })).to(equal(collection["data"]))
    }

    // Given an `UpdateResult`, verify that it matches the expected results in this `CrudTest`.
    // Meant for use by subclasses whose operations return `UpdateResult`s, such as `UpdateTest`
    // and `ReplaceOneTest`.
    func verifyUpdateResult(_ result: UpdateResult?) throws {
        let expected = try BSONDecoder().decode(UpdateResult.self, from: self.result!.documentValue!)
        expect(result?.matchedCount).to(equal(expected.matchedCount))
        expect(result?.modifiedCount).to(equal(expected.modifiedCount))
        expect(result?.upsertedCount).to(equal(expected.upsertedCount))

        if let upsertedID = result?.upsertedID {
            expect(upsertedID).to(equal(expected.upsertedID))
        } else {
            expect(expected.upsertedID).to(beNil())
        }
    }

    /// Given the response to a findAndModify command, verify that it matches the expected
    /// results for this `CrudTest`. Meant for use by findAndModify subclasses, i.e. findOneAndX.
    func verifyFindAndModifyResult(_ result: BSONDocument?) {
        guard self.result != nil else {
            return
        }
        if self.result == .null {
            expect(result).to(beNil())
        } else {
            expect(result).to(equal(self.result?.documentValue))
        }
    }
}

/// A class for executing `aggregate` tests
private class AggregateTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let pipeline = self.args["pipeline"]!.arrayValue!.compactMap(\.documentValue)
        let options = AggregateOptions(batchSize: self.batchSize, collation: self.collation)
        let cursor = try coll.aggregate(pipeline, options: options)
        if self.collection != nil {
            // this is $out case - we need to iterate the cursor once in
            // order to make the aggregation happen. there is nothing in
            // the cursor to verify, but verifyData() will check that the
            // $out collection has the new data.
            expect(cursor.next()).to(beNil())
        } else {
            // if not $out, verify that the cursor contains the expected documents.
            expect(BSON.array(try cursor.all().map { .document($0) })).to(equal(self.result))
        }
    }
}

private class BulkWriteTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let requestDocuments: [BSONDocument] = self.args["requests"]!.arrayValue!.compactMap(\.documentValue)
        let requests = try requestDocuments.map { try BSONDecoder().decode(WriteModel<BSONDocument>.self, from: $0) }
        let options = try BSONDecoder().decode(BulkWriteOptions.self, from: self.args["options"]?.documentValue ?? [:])
        let expectError = self.error ?? false

        do {
            if let result = try coll.bulkWrite(requests, options: options) {
                self.verifyBulkWriteResult(result)
            }
            expect(expectError).to(beFalse())
        } catch let bwe as MongoError.BulkWriteError {
            if let result = bwe.result {
                verifyBulkWriteResult(result)
            }
            expect(expectError).to(beTrue())
        }
    }

    private static func prepareIds(_ ids: [Int: BSON]) -> BSONDocument {
        var document = BSONDocument()

        // Dictionaries are unsorted. Sort before comparing with expected map
        for (index, id) in ids.sorted(by: { $0.key < $1.key }) {
            document[String(index)] = id
        }

        return document
    }

    private func verifyBulkWriteResult(_ result: BulkWriteResult) {
        guard let expected = self.result?.documentValue else {
            return
        }

        if let expectedDeletedCount = expected["deletedCount"]?.toInt() {
            expect(result.deletedCount).to(equal(expectedDeletedCount))
        }
        if let expectedInsertedCount = expected["insertedCount"]?.toInt() {
            expect(result.insertedCount).to(equal(expectedInsertedCount))
        }
        if let expectedInsertedIds = expected["insertedIDs"]?.documentValue {
            expect(BulkWriteTest.prepareIds(result.insertedIDs)).to(equal(expectedInsertedIds))
        }
        if let expectedMatchedCount = expected["matchedCount"]?.toInt() {
            expect(result.matchedCount).to(equal(expectedMatchedCount))
        }
        if let expectedModifiedCount = expected["modifiedCount"]?.toInt() {
            expect(result.modifiedCount).to(equal(expectedModifiedCount))
        }
        if let expectedUpsertedCount = expected["upsertedCount"]?.toInt() {
            expect(result.upsertedCount).to(equal(expectedUpsertedCount))
        }
        if let expectedUpsertedIds = expected["upsertedIDs"]?.documentValue {
            expect(BulkWriteTest.prepareIds(result.upsertedIDs)).to(equal(expectedUpsertedIds))
        }
    }
}

/// A class for executing `count` tests
private class CountTest: CrudTest {
    override func execute(usingCollection _: MongoCollection<BSONDocument>) throws {}
}

/// A class for executing `countDocuments` tests
private class CountDocumentsTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let options = CountDocumentsOptions(collation: self.collation, limit: self.limit, skip: self.skip)
        let result = try coll.countDocuments(filter, options: options)
        expect(result).to(equal(self.result?.toInt()))
    }
}

/// A class for executing `estimatedDocumentCount` tests
private class EstimatedDocumentCountTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let options = EstimatedDocumentCountOptions()
        let result = try coll.estimatedDocumentCount(options: options)
        expect(result).to(equal(self.result?.toInt()))
    }
}

/// A class for executing `deleteOne` and `deleteMany` tests
private class DeleteTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let options = DeleteOptions(collation: self.collation)
        let result: DeleteResult?
        if self.operationName == "deleteOne" {
            result = try coll.deleteOne(filter, options: options)
        } else {
            result = try coll.deleteMany(filter, options: options)
        }
        let expected = self.result?.documentValue
        // the only value in a DeleteResult is `deletedCount`
        expect(result?.deletedCount).to(equal(expected?["deletedCount"]?.toInt()))
    }
}

/// A class for executing `distinct` tests
private class DistinctTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter = self.args["filter"]?.documentValue
        let fieldName: String = try self.args.get("fieldName")
        let options = DistinctOptions(collation: self.collation)
        // rather than casting to all the possible BSON types, just wrap the arrays in documents to compare them
        let resultDoc: BSONDocument = [
            "result": .array(try coll.distinct(fieldName: fieldName, filter: filter ?? [:], options: options))
        ]
        if let result = self.result {
            let expectedDoc: BSONDocument = ["result": result]
            expect(resultDoc).to(equal(expectedDoc))
        }
    }
}

/// A class for executing `find` tests
private class FindTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let options = FindOptions(
            batchSize: self.batchSize,
            collation: self.collation,
            limit: self.limit,
            skip: self.skip,
            sort: self.sort
        )
        let result = BSON.array(try coll.find(filter, options: options).all().map { .document($0) })
        expect(result).to(equal(self.result))
    }
}

/// A class for executing `findOneAndDelete` tests
private class FindOneAndDeleteTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let opts = FindOneAndDeleteOptions(collation: self.collation, projection: self.projection, sort: self.sort)

        let result = try coll.findOneAndDelete(filter, options: opts)
        self.verifyFindAndModifyResult(result)
    }
}

/// A class for executing `findOneAndUpdate` tests
private class FindOneAndReplaceTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let replacement: BSONDocument = try self.args.get("replacement")

        let opts = FindOneAndReplaceOptions(
            collation: self.collation,
            projection: self.projection,
            returnDocument: self.returnDoc,
            sort: self.sort,
            upsert: self.upsert
        )

        let result = try coll.findOneAndReplace(filter: filter, replacement: replacement, options: opts)
        self.verifyFindAndModifyResult(result)
    }
}

/// A class for executing `findOneAndReplace` tests
private class FindOneAndUpdateTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let update: BSONDocument = try self.args.get("update")

        let opts = FindOneAndUpdateOptions(
            arrayFilters: self.arrayFilters,
            collation: self.collation,
            projection: self.projection,
            returnDocument: self.returnDoc,
            sort: self.sort,
            upsert: self.upsert
        )

        let result = try coll.findOneAndUpdate(filter: filter, update: update, options: opts)
        self.verifyFindAndModifyResult(result)
    }
}

/// A class for executing `insertMany` tests
private class InsertManyTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let documents = self.args["documents"]!.arrayValue!.compactMap(\.documentValue)
        let options = InsertManyTest.parseInsertManyOptions(self.args["options"]?.documentValue)
        let expectError = self.error ?? false

        do {
            if let result = try coll.insertMany(documents, options: options) {
                self.verifyInsertManyResult(result)
            }
            expect(expectError).to(beFalse())
        } catch let bwe as MongoError.BulkWriteError {
            if let result = bwe.result {
                verifyInsertManyResult(InsertManyResult.fromBulkResult(result)!)
            }
            expect(expectError).to(beTrue())
        }
    }

    private static func parseInsertManyOptions(_ options: BSONDocument?) -> InsertManyOptions? {
        guard let options = options else {
            return nil
        }

        let ordered = options["ordered"]?.boolValue

        return InsertManyOptions(ordered: ordered)
    }

    private static func prepareIds(_ ids: [Int: BSON]) -> BSONDocument {
        var document = BSONDocument()

        // Dictionaries are unsorted. Sort before comparing with expected map
        for (index, id) in ids.sorted(by: { $0.key < $1.key }) {
            document[String(index)] = id
        }

        return document
    }

    private func verifyInsertManyResult(_ result: InsertManyResult) {
        guard let expected = self.result?.documentValue else {
            return
        }

        if let expectedInsertedCount = expected["insertedCount"]?.toInt() {
            expect(result.insertedCount).to(equal(expectedInsertedCount))
        }
        if let expectedInsertedIds = expected["insertedIDs"]?.documentValue {
            expect(InsertManyTest.prepareIds(result.insertedIDs)).to(equal(expectedInsertedIds))
        }
    }
}

/// A Class for executing `insertOne` tests
private class InsertOneTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let doc: BSONDocument = try self.args.get("document")
        let result = try coll.insertOne(doc)
        expect(doc["_id"]).to(equal(result?.insertedID))
    }
}

/// A class for executing `replaceOne` tests
private class ReplaceOneTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let replacement: BSONDocument = try self.args.get("replacement")
        let options = ReplaceOptions(collation: self.collation, upsert: self.upsert)
        let result = try coll.replaceOne(filter: filter, replacement: replacement, options: options)
        try self.verifyUpdateResult(result)
    }
}

/// A class for executing `updateOne` and `updateMany` tests
private class UpdateTest: CrudTest {
    override func execute(usingCollection coll: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = try self.args.get("filter")
        let update: BSONDocument = try self.args.get("update")
        let options = UpdateOptions(arrayFilters: self.arrayFilters, collation: self.collation, upsert: self.upsert)
        let result: UpdateResult?
        if self.operationName == "updateOne" {
            result = try coll.updateOne(filter: filter, update: update, options: options)
        } else {
            result = try coll.updateMany(filter: filter, update: update, options: options)
        }
        try self.verifyUpdateResult(result)
    }
}
