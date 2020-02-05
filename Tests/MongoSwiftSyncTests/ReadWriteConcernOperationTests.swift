import CLibMongoC
@testable import MongoSwift
import MongoSwiftSync
import Nimble
import TestsCommon

final class ReadWriteConcernOperationTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testOperationReadConcerns() throws {
        // setup a collection
        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName())

        let command: Document = ["count": .string(coll.name)]

        // run command with a valid readConcern
        let options1 = RunCommandOptions(readConcern: ReadConcern(.local))
        let res1 = try db.runCommand(command, options: options1)
        expect(res1["ok"]?.asDouble()).to(equal(1.0))

        // run command with an empty readConcern
        let options2 = RunCommandOptions(readConcern: ReadConcern())
        let res2 = try db.runCommand(command, options: options2)
        expect(res2["ok"]?.asDouble()).to(equal(1.0))

        // running command with an invalid RC level should throw
        let options3 = RunCommandOptions(readConcern: ReadConcern("blah"))
        // error code 9: FailedToParse
        expect(try db.runCommand(command, options: options3))
            .to(throwError(CommandError(
                code: 9,
                codeName: "FailedToParse",
                message: "",
                errorLabels: nil
            )))

        // try various command + read concern pairs to make sure they work
        expect(try coll.find(options: FindOptions(readConcern: ReadConcern(.local)))).toNot(throwError())
        expect(try coll.findOne(options: FindOneOptions(readConcern: ReadConcern(.local)))).toNot(throwError())

        expect(try coll.aggregate(
            [["$project": ["a": 1]]],
            options: AggregateOptions(readConcern: ReadConcern(.majority))
        )).toNot(throwError())

        expect(try coll.countDocuments(options: CountDocumentsOptions(readConcern: ReadConcern(.majority))))
            .toNot(throwError())

        expect(try coll.estimatedDocumentCount(
            options:
            EstimatedDocumentCountOptions(readConcern: ReadConcern(.majority))
        )).toNot(throwError())

        expect(try coll.distinct(
            fieldName: "a",
            options: DistinctOptions(readConcern: ReadConcern(.local))
        )).toNot(throwError())
    }

    func testWriteConcernErrors() throws {
        // Because the error codes differ between sharded clusters and replica sets for the same command (and the
        // sharded error is pretty gross), we just skip the sharded clusters. Also, a WriteConcernError isn't
        // encountered on standalones, so we skip those as well.
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let wc = try WriteConcern(w: .number(45))
        let expectedWCError =
            WriteConcernFailure(code: 100, codeName: "", details: nil, message: "")
        let expectedWriteError =
            WriteError(writeFailure: nil, writeConcernFailure: expectedWCError, errorLabels: nil)
        let expectedBulkResult = BulkWriteResult(insertedCount: 1, insertedIds: [0: 1])
        let expectedBulkError = BulkWriteError(
            writeFailures: [],
            writeConcernFailure: expectedWCError,
            otherError: nil,
            result: expectedBulkResult,
            errorLabels: nil
        )

        let client = try MongoClient.makeTestClient()
        let database = client.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())
        defer { try? collection.drop() }

        expect(try collection.insertOne(["x": 1], options: InsertOneOptions(writeConcern: wc)))
            .to(throwError(expectedWriteError))

        expect(try collection.bulkWrite([.insertOne(["_id": 1])], options: BulkWriteOptions(writeConcern: wc)))
            .to(throwError(expectedBulkError))
    }

    func testOperationWriteConcerns() throws {
        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        var counter = 0
        func nextDoc() -> Document {
            defer { counter += 1 }
            return ["x": BSON(integerLiteral: counter)]
        }

        let coll = try db.createCollection(self.getCollectionName())
        let wc1 = try WriteConcern(w: .number(1))
        let wc2 = WriteConcern()
        let wc3 = try WriteConcern(journal: true)

        let command: Document = ["insert": .string(coll.name), "documents": [.document(nextDoc())]]

        // run command with a valid writeConcern
        let options1 = RunCommandOptions(writeConcern: wc1)
        let res1 = try db.runCommand(command, options: options1)
        expect(res1["ok"]?.asDouble()).to(equal(1.0))

        // run command with an empty writeConcern
        let options2 = RunCommandOptions(writeConcern: wc2)
        let res2 = try db.runCommand(command, options: options2)
        expect(res2["ok"]?.asDouble()).to(equal(1.0))

        expect(try coll.insertOne(nextDoc(), options: InsertOneOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.insertOne(nextDoc(), options: InsertOneOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.insertMany(
            [nextDoc(), nextDoc()],
            options: InsertManyOptions(writeConcern: wc1)
        )).toNot(throwError())
        expect(try coll.insertMany(
            [nextDoc(), nextDoc()],
            options: InsertManyOptions(writeConcern: wc3)
        )).toNot(throwError())

        expect(try coll.updateOne(
            filter: ["x": 1],
            update: ["$set": .document(nextDoc())],
            options: UpdateOptions(writeConcern: wc2)
        )).toNot(throwError())
        expect(try coll.updateOne(
            filter: ["x": 2],
            update: ["$set": .document(nextDoc())],
            options: UpdateOptions(writeConcern: wc3)
        )).toNot(throwError())

        expect(try coll.updateMany(
            filter: ["x": 3],
            update: ["$set": .document(nextDoc())],
            options: UpdateOptions(writeConcern: wc2)
        )).toNot(throwError())
        expect(try coll.updateMany(
            filter: ["x": 4],
            update: ["$set": .document(nextDoc())],
            options: UpdateOptions(writeConcern: wc3)
        )).toNot(throwError())

        let coll2 = try db.createCollection(self.getCollectionName(suffix: "2"))
        defer { try? coll2.drop() }

        let pipeline: [Document] = [["$out": .string("\(db.name).\(coll2.name)")]]
        expect(try coll.aggregate(pipeline, options: AggregateOptions(writeConcern: wc1))).toNot(throwError())

        expect(try coll.replaceOne(
            filter: ["x": 5],
            replacement: nextDoc(),
            options: ReplaceOptions(writeConcern: wc1)
        )).toNot(throwError())
        expect(try coll.replaceOne(
            filter: ["x": 6],
            replacement: nextDoc(),
            options: ReplaceOptions(writeConcern: wc3)
        )).toNot(throwError())

        expect(try coll.deleteOne(["x": 7], options: DeleteOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.deleteOne(["x": 8], options: DeleteOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.deleteMany(["x": 9], options: DeleteOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.deleteMany(["x": 10], options: DeleteOptions(writeConcern: wc3))).toNot(throwError())

        // TODO: SWIFT-702: uncomment these assertions
        // expect(try coll.createIndex(
        //     ["x": 1],
        //     options: CreateIndexOptions(writeConcern: wc1)
        // )).toNot(throwError())
        // expect(try coll.createIndexes(
        //     [IndexModel(keys: ["x": -1])],
        //     options: CreateIndexOptions(writeConcern: wc3)
        // )).toNot(throwError())

        // expect(try coll.dropIndex(["x": 1], options: DropIndexOptions(writeConcern: wc1))).toNot(throwError())
        // expect(try coll.dropIndexes(options: DropIndexOptions(writeConcern: wc3))).toNot(throwError())
    }
}
