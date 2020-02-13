import Foundation
@testable import MongoSwift
import Nimble
import NIO
import TestsCommon

private let doc1: Document = ["_id": 1, "x": 1]
private let doc2: Document = ["_id": 2, "x": 2]
private let doc3: Document = ["_id": 3, "x": 3]

final class AsyncMongoCursorTests: MongoSwiftTestCase {
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }

    func testNonTailableCursor() throws {
        try self.withTestNamespace { _, db, coll in
            // query empty collection
            var cursor = try coll.find().wait()
            expect(try cursor.next().wait()).toNot(throwError())
            // cursor should immediately be closed as its empty
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))

            // insert and read out one document
            _ = try coll.insertOne(doc1).wait()
            cursor = try coll.find().wait()
            let results = try cursor.toArray().wait()
            expect(results).to(haveCount(1))
            expect(results[0]).to(equal(doc1))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating a dead cursor should error
            expect(try cursor.next().wait()).to(throwError())

            cursor = try coll.find(options: FindOptions(batchSize: 1)).wait()
            expect(try cursor.next().wait()).toNot(throwError())

            // run killCursors so next iteration fails on the server
            _ = try db.runCommand(["killCursors": .string(coll.name), "cursors": [.int64(cursor.id!)]]).wait()
            let expectedError = CommandError.new(
                code: 43,
                codeName: "CursorNotFound",
                message: "",
                errorLabels: nil
            )
            expect(try cursor.next().wait()).to(throwError(expectedError))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())
        }
    }

    func testTailableAwaitAsyncCursor() throws {
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(batchSize: 1, cursorType: .tailableAwait, maxAwaitTimeMS: 10)
            _ = try coll.insertMany([Document()]).wait()

            let cursor = try coll.find(options: cursorOpts).wait()
            let doc = try cursor.next().wait()
            expect(doc).toNot(beNil())

            let future = cursor.next()
            _ = try coll.insertMany([Document()]).wait()
            expect(try future.wait()).toNot(beNil())

            expect(try cursor.tryNext().wait()).to(beNil())

            // start polling and interrupt with close
            let interruptedFuture = cursor.next()

            expect(try cursor.kill().wait()).toNot(throwError())
            expect(try interruptedFuture.wait()).to(beNil())
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))
        }
    }

    func testTailableAsyncCursor() throws {
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(cursorType: .tailable)

            var cursor = try coll.find(options: cursorOpts).wait()
            expect(try cursor.next().wait()).to(beNil())
            // no documents matched initial query, so cursor is dead
            expect(cursor.isAlive).to(beFalse())
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))

            // insert a doc so something matches initial query
            _ = try coll.insertOne(doc1).wait()
            cursor = try coll.find(options: cursorOpts).wait()

            // for each doc we insert, check that it arrives in the cursor next,
            // and that the cursor is still alive afterward
            let checkNextResult: (Document) throws -> Void = { doc in
                let results = try cursor.toArray().wait()
                expect(results).to(haveCount(1))
                expect(results[0]).to(equal(doc))
                expect(cursor.isAlive).to(beTrue())
            }
            try checkNextResult(doc1)

            _ = try coll.insertOne(doc2).wait()
            try checkNextResult(doc2)

            _ = try coll.insertOne(doc3).wait()
            try checkNextResult(doc3)

            // no more docs, but should still be alive
            expect(try cursor.tryNext().wait()).to(beNil())
            expect(cursor.isAlive).to(beTrue())

            // insert 3 docs so the cursor loses track of its position
            for i in 4..<7 {
                _ = try coll.insertOne(["_id": BSON(i), "x": BSON(i)]).wait()
            }

            let expectedError = CommandError.new(
                code: 136,
                codeName: "CappedPositionLost",
                message: "",
                errorLabels: nil
            )
            expect(try cursor.next().wait()).to(throwError(expectedError))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())

            // iterating dead cursor should error
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))
        }
    }

    func testAsyncNext() throws {
        try self.withTestNamespace { _, _, coll in
            // query empty collection
            var cursor = try coll.find().wait()
            expect(try cursor.next().wait()).to(beNil())
            expect(cursor.isAlive).to(beFalse())

            // insert a doc so something matches initial query
            _ = try coll.insertOne(doc1).wait()
            cursor = try coll.find().wait()

            let doc = try cursor.next().wait()
            expect(doc).toNot(beNil())
            expect(doc).to(equal(doc1))

            expect(try cursor.next().wait()).to(beNil())
            expect(cursor.isAlive).to(beFalse())

            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))
        }
    }

    func testCursorToArray() throws {
        // normal cursor
        try self.withTestNamespace { _, _, coll in
            // query empty collection
            var cursor = try coll.find().wait()
            expect(try cursor.toArray().wait()).to(equal([]))
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))

            // iterating after calling toArray should error.
            _ = try coll.insertMany([doc1, doc2, doc3]).wait()
            cursor = try coll.find().wait()
            var results = try cursor.toArray().wait()
            expect(results).to(equal([doc1, doc2, doc3]))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))

            // calling toArray on a closed cursor should error.
            cursor = try coll.find().wait()
            results = try cursor.toArray().wait()
            expect(results).to(haveCount(3))
            expect(try cursor.toArray().wait()).to(throwError())
        }

        // tailable cursor
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(cursorType: .tailable)

            var cursor = try coll.find(options: cursorOpts).wait()
            defer { try? cursor.kill().wait() }

            expect(try cursor.toArray().wait()).to(beEmpty())
            // no documents matched initial query, so cursor is dead
            expect(cursor.isAlive).to(beFalse())
            expect(try cursor.next().wait()).to(throwError(errorType: LogicError.self))

            // insert a doc so something matches initial query
            _ = try coll.insertOne(doc1).wait()
            cursor = try coll.find(options: cursorOpts).wait()
            expect(try cursor.toArray().wait()).to(equal([doc1]))
            expect(cursor.isAlive).to(beTrue())

            // newly inserted docs will be returned by toArray
            _ = try coll.insertMany([doc2, doc3]).wait()
            expect(try cursor.toArray().wait()).to(equal([doc2, doc3]))
            expect(cursor.isAlive).to(beTrue())
        }
    }

    func testForEach() throws {
        var count = 0
        let increment: (Document) -> Void = { _ in count += 1 }

        // non-tailable
        try self.withTestNamespace { _, _, coll in
            // empty collection
            var cursor = try coll.find().wait()
            _ = try cursor.forEach(increment).wait()
            expect(count).to(equal(0))
            expect(cursor.isAlive).to(beFalse())

            _ = try coll.insertMany([doc1, doc2]).wait()

            // non empty
            cursor = try coll.find().wait()
            _ = try cursor.forEach(increment).wait()
            expect(count).to(equal(2))
            expect(cursor.isAlive).to(beFalse())
        }

        count = 0
        // tailable
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(cursorType: .tailable)

            var cursor = try coll.find(options: cursorOpts).wait()
            _ = try cursor.forEach(increment).wait()
            expect(count).to(equal(0))
            // no documents matched initial query, so cursor is dead
            expect(cursor.isAlive).to(beFalse())

            _ = try coll.insertMany([doc1, doc2]).wait()
            cursor = try coll.find(options: cursorOpts).wait()

            // start running forEach; future will not resolve since cursor is tailable
            let future = cursor.forEach(increment)
            expect(count).toEventually(equal(2))

            expect(cursor.isAlive).to(beTrue())
            // killing the cursor should resolve the future and not error
            expect(try cursor.kill().wait()).toNot(throwError())
            expect(try future.wait()).to(beAnInstanceOf(Void.self))

            // calling forEach on a dead cursor should error
            expect(try cursor.forEach(increment).wait()).to(throwError(errorType: LogicError.self))
        }
    }
}
