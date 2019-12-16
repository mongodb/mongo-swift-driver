import Foundation
import MongoSwift
import Nimble
import TestsCommon

private let doc1: Document = ["_id": 1, "x": 1]
private let doc2: Document = ["_id": 2, "x": 2]
private let doc3: Document = ["_id": 3, "x": 3]

final class MongoCursorTests: MongoSwiftTestCase {
    func testNonTailableCursor() throws {
        try self.withTestNamespace { _, db, coll in
            // query empty collection
            var cursor = try coll.find()
            expect(try cursor.nextOrError()).toNot(throwError())
            // cursor should immediately be closed as its empty
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.nextOrError()).to(throwError(LOGIC_ERROR))

            // insert and read out one document
            try coll.insertOne(doc1)
            cursor = try coll.find()
            var results = Array(cursor)
            expect(results).to(haveCount(1))
            expect(results[0]).to(equal(doc1))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.nextOrError()).to(throwError())

            try coll.insertMany([doc2, doc3])
            cursor = try coll.find()
            results = Array(cursor)
            expect(results).to(haveCount(3))
            expect(results).to(equal([doc1, doc2, doc3]))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.nextOrError()).to(throwError(LOGIC_ERROR))

            cursor = try coll.find(options: FindOptions(batchSize: 1))
            expect(try cursor.nextOrError()).toNot(throwError())

            // run killCursors so next iteration fails on the server
            try db.runCommand(["killCursors": .string(coll.name), "cursors": [.int64(cursor.id!)]])
            let expectedError2 = CommandError.new(
                code: 43,
                codeName: "CursorNotFound",
                message: "",
                errorLabels: nil
            )
            expect(try cursor.nextOrError()).to(throwError(expectedError2))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())
        }
    }

    func testTailableCursor() throws {
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(cursorType: .tailable)

            var cursor = try coll.find(options: cursorOpts)
            expect(try cursor.nextOrError()).to(beNil())
            // no documents matched initial query, so cursor is dead
            expect(cursor.isAlive).to(beFalse())
            // iterating iterating dead cursor should error
            expect(try cursor.nextOrError()).to(throwError(LOGIC_ERROR))

            // insert a doc so something matches initial query
            try coll.insertOne(doc1)
            cursor = try coll.find(options: cursorOpts)

            // for each doc we insert, check that it arrives in the cursor next,
            // and that the cursor is still alive afterward
            let checkNextResult: (Document) -> Void = { doc in
                let results = Array(cursor)
                expect(results).to(haveCount(1))
                expect(results[0]).to(equal(doc))
                expect(cursor.error).to(beNil())
                expect(cursor.isAlive).to(beTrue())
            }
            checkNextResult(doc1)

            try coll.insertOne(doc2)
            checkNextResult(doc2)

            try coll.insertOne(doc3)
            checkNextResult(doc3)

            // no more docs, but should still be alive
            expect(try cursor.nextOrError()).to(beNil())
            expect(cursor.isAlive).to(beTrue())

            // insert 3 docs so the cursor loses track of its position
            for i in 4..<7 {
                try coll.insertOne(["_id": BSON(i), "x": BSON(i)])
            }

            let expectedError = CommandError.new(
                code: 136,
                codeName: "CappedPositionLost",
                message: "",
                errorLabels: nil
            )
            expect(try cursor.nextOrError()).to(throwError(expectedError))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())

            // iterating dead cursor should error
            expect(try cursor.nextOrError()).to(throwError(LOGIC_ERROR))
        }
    }
}
