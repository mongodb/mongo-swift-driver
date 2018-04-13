import Foundation
@testable import MongoSwift
import XCTest
import Nimble

let tweetFile = URL(fileURLWithPath: basePath + "/tweet.json")
let tweetSize = 16.22
let smallFile = URL(fileURLWithPath: basePath + "/small_doc.json")
let smallSize = 2.75
let largeFile = URL(fileURLWithPath: basePath + "/large_doc.json")
let largeSize = 27.31

let commandSize = 0.16

func setup() throws -> (MongoDatabase, MongoCollection) {
    let db = try MongoClient().db("perftest")
    try db.drop()
    return (db, try db.createCollection("corpus"))
}

final class SingleDocumentBenchmarks: XCTestCase {

    func testRunCommand() throws {
        // setup 
        let (db, _) = try setup()
        let command: Document = ["ismaster": true]

        // Run the command {ismaster:true} 10,000 times, 
        // reading (and discarding) the result each time.
        let result = try measureOp({
            for _ in 1...10000 {
                _ = try db.runCommand(command)
            }
        })

        printResults(time: result, size: commandSize)
    }

    func testFindOneById() throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: tweetFile, encoding: .utf8)

        // Insert the document 10,000 times to the 'perftest' database in the 'corpus'
        //  collection using sequential _id values. (1 to 10,000)
        var toInsert = [Document]()
        for i in 1...10000 {
            var document = try Document(fromJSON: jsonString)
            document["_id"] = i
            toInsert.append(document)
        }

        _ = try collection.insertMany(toInsert)

        // make sure the documents were actually inserted
        expect(try collection.count([:])).to(equal(10000))

        let result = try measureOp({
            // For each of the 10,000 sequential _id numbers, issue a find command for 
            // that _id on the 'corpus' collection and retrieve the single-document result.
            for i in 1...10000 {
                // iterate the cursor so we actually "read" the result
                _ = try collection.find(["_id": i]).next()
            }
        })

        printResults(time: result, size: tweetSize)

        // teardown
        try db.drop()
    }

    func doInsertOneTest(file: URL, size: Double, numDocs: Int, iterations: Int = 100) throws {
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: file, encoding: .utf8)

        var results = [Double]()

        for _ in 1...iterations {

            // since we can't re-insert the same object, create `numDocs`
            // copies of the document for each run
            var documents = [Document]()
            for _ in 1...numDocs {
                documents.append(try Document(fromJSON: jsonString))
            }

            // Insert the document with the insertOne CRUD method. DO NOT manually add an _id field;
            // leave it to the driver or database. Repeat this `numDocs` times.
            results.append(try measureTime({
                for doc in documents {
                    _ = try collection.insertOne(doc)
                }
            }))

            expect(try collection.count([:])).to(equal(numDocs))

            // cleanup before the next measure run
            try collection.drop()
        }

        printResults(time: median(results), size: size)

        // teardown
        try db.drop()
    }

    func testSmallDocInsertOne() throws {
        try doInsertOneTest(file: smallFile, size: smallSize, numDocs: 10000)
    }

    func testLargeDocInsertOne() throws {
        try doInsertOneTest(file: largeFile, size: largeSize, numDocs: 10, iterations: 200)
    }
}

public class MultiDocumentBenchmarks: XCTestCase {

    func testFindManyAndEmptyCursor() throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: tweetFile, encoding: .utf8)
        for _ in 1...10000 {
            _ = try collection.insertOne(try Document(fromJSON: jsonString))
        }

        // make sure the documents were actually inserted
        expect(try collection.count([:])).to(equal(10000))

        // Issue a find command on the 'corpus' collection with an empty filter expression. 
        // Retrieve (and discard) all documents from the cursor.
        let result = try measureOp({
            for _ in try collection.find() {}
        }, iterations: 3000) // short test - increase # of iterations so cumulative time is > 1 minute

        printResults(time: result, size: tweetSize)

        // teardown
        try db.drop()
    }

    func doBulkInsertTest(file: URL, size: Double, numDocs: Int, iterations: Int = 100) throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: file, encoding: .utf8)

        var results = [Double]()

        for _ in 1...iterations {
            var documents = [Document]()
            for _ in 1...numDocs {
                documents.append(try Document(fromJSON: jsonString))
            }

            // Do an ordered 'insert_many' with `numDocs` copies of the document.
            // DO NOT manually add an _id field; leave it to the driver or database.
            results.append(try measureTime({
                _ = try collection.insertMany(documents)
            }))

            // make sure the documents were actually inserted
            expect(try collection.count([:])).to(equal(numDocs))

            // cleanup before next run
            try collection.drop()
        }

        printResults(time: median(results), size: size)

        // teardown
        try db.drop()
    }

    func testSmallDocBulkInsert() throws {
        try doBulkInsertTest(file: smallFile, size: smallSize, numDocs: 10000, iterations: 400)
    }

    func testLargeDocBulkInsert() throws {
        try doBulkInsertTest(file: largeFile, size: largeSize, numDocs: 10, iterations: 200)
    }
}
