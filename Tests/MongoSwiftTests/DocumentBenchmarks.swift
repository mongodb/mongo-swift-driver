import Foundation
@testable import MongoSwift
import XCTest

let tweetFile = URL(fileURLWithPath: basePath + "tweet.json")
let smallFile = URL(fileURLWithPath: basePath + "small_doc.json")
let largeFile = URL(fileURLWithPath: basePath + "large_doc.json")

func setup() throws -> (MongoDatabase, MongoCollection) {
    let db = try MongoClient().db("perftest")
    try db.drop()
    return (db, try db.createCollection("corpus"))
}

public class SingleDocumentBenchmarks: XCTestCase {

    // average: 0.757 vs 0.711768
    func testRunCommand() throws {
        // setup 
        let (db, _) = try setup()
        let command: Document = ["ismaster": true]

        measure {
            // Run the command {ismaster:true} 10,000 times, reading (and discarding) the result each time.
            for _ in 1...10000 {
                 do { _ = try db.runCommand(command: command) } catch { XCTFail("error \(error)") }
            }
        }
    }

    // average: 1.305 vs 1.094534
    func testFindOneById() throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: tweetFile, encoding: .utf8)

        // Insert the document 10,000 times to the 'perftest' database in the 'corpus'
        //  collection using sequential _id values. (1 to 10,000)
        for i in 1...10000 {
            let document = try Document(fromJSON: jsonString)
            document["_id"] = i
            _ = try collection.insertOne(document)
        }

        // make sure the documents were actually inserted
        XCTAssertEqual(try collection.count([:]), 10000)

        measure {
            // For each of the 10,000 sequential _id numbers, issue a find command for 
            // that _id on the 'corpus' collection and retrieve the single-document result.
            for i in 1...10000 {
                do {
                    // iterate the cursor so we actually "read" the result
                    _ = try collection.find(["_id": i]).next()
                } catch { XCTFail("error \(error)") }
            }
        }

        // teardown
        try db.drop()
    }

    func doInsertOneTest(file: URL, numDocs: Int) throws {
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: file, encoding: .utf8)

        // Insert the document with the insertOne CRUD method. DO NOT manually add an _id field;
        // leave it to the driver or database. Repeat this `numDocs` times.
        measureMetrics([XCTPerformanceMetric_WallClockTime],
            automaticallyStartMeasuring: false, for: {
                do {
                    // since we can't re-insert the same object, create `numDocs`
                    // copies of the document for each measure() run
                    var documents = [Document]()
                    for _ in 1...numDocs {
                        documents.append(try Document(fromJSON: jsonString))
                    }
                    self.startMeasuring()
                    for doc in documents {
                        _ = try collection.insertOne(doc)
                    }

                    self.stopMeasuring()
                    // make sure the documents were actually inserted
                    XCTAssertEqual(try collection.count([:]), numDocs)
                    // cleanup before the next measure run
                    try collection.drop()

                } catch { XCTFail("error \(error)") }
        })

        // teardown
        try db.drop()
    }

    // average: 1.429 vs 1.099623
    func testSmallDocInsertOne() throws {
        try doInsertOneTest(file: smallFile, numDocs: 10000)
    }

    // average: 0.688 vs 0.430373
    func testLargeDocInsertOne() throws {
        try doInsertOneTest(file: largeFile, numDocs: 10)
    }
}

public class MultiDocumentBenchmarks: XCTestCase {

    // average: 0.027 vs 0.000988
    func testFindManyAndEmptyCursor() throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: tweetFile, encoding: .utf8)
        for _ in 1...10000 {
            _ = try collection.insertOne(try Document(fromJSON: jsonString))
        }

        // make sure the documents were actually inserted
        XCTAssertEqual(try collection.count([:]), 10000)

        // Issue a find command on the 'corpus' collection with an empty filter expression. 
        // Retrieve (and discard) all documents from the cursor.
        measure {
            do { for _ in try collection.find([:]) {} } catch { XCTFail("error \(error)") }
        }

        // teardown
        try db.drop()
    }

    func doBulkInsertTest(file: URL, numDocs: Int) throws {
        // setup
        let (db, collection) = try setup()
        let jsonString = try String(contentsOf: file, encoding: .utf8)

        // Do an ordered 'insert_many' with `numDocs` copies of the document.
        // DO NOT manually add an _id field; leave it to the driver or database.
        measureMetrics([XCTPerformanceMetric_WallClockTime],
            automaticallyStartMeasuring: false, for: {
                do {
                    var documents = [Document]()
                    for _ in 1...numDocs {
                        documents.append(try Document(fromJSON: jsonString))
                    }
                    self.startMeasuring()
                    _ = try collection.insertMany(documents)
                    self.stopMeasuring()

                    // make sure the documents were actually inserted
                    XCTAssertEqual(try collection.count([:]), numDocs)

                    // cleanup before next measure() run
                    try collection.drop()

                } catch { XCTFail("error \(error)") }
        })

        // teardown
        try db.drop()
    }

    // average: 0.189 vs 0.244671
    func testSmallDocBulkInsert() throws {
        try doBulkInsertTest(file: smallFile, numDocs: 10000)
    }

    // average: 0.696 vs 0.32657
    func testLargeDocBulkInsert() throws {
        try doBulkInsertTest(file: largeFile, numDocs: 10)
    }
}
