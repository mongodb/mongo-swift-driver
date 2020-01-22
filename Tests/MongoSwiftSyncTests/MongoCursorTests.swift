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
            expect(try cursor.next()?.get()).toNot(throwError())
            // cursor should immediately be closed as its empty
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))

            // insert and read out one document
            try coll.insertOne(doc1)
            cursor = try coll.find()
            var results = try Array(cursor.all())
            expect(results).to(haveCount(1))
            expect(results[0]).to(equal(doc1))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next()?.get()).to(throwError())

            try coll.insertMany([doc2, doc3])
            cursor = try coll.find()
            results = try Array(cursor.all())
            expect(results).to(haveCount(3))
            expect(results).to(equal([doc1, doc2, doc3]))
            // cursor should be closed now that its exhausted
            expect(cursor.isAlive).to(beFalse())
            // iterating dead cursor should error
            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))

            cursor = try coll.find(options: FindOptions(batchSize: 1))
            expect(try cursor.next()?.get()).toNot(throwError())

            // run killCursors so next iteration fails on the server
            try db.runCommand(["killCursors": .string(coll.name), "cursors": [.int64(cursor.id!)]])
            let expectedError2 = CommandError.new(
                code: 43,
                codeName: "CursorNotFound",
                message: "",
                errorLabels: nil
            )
            expect(try cursor.next()?.get()).to(throwError(expectedError2))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())
        }
    }

    func testTailableCursor() throws {
        let collOptions = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(collectionOptions: collOptions) { _, _, coll in
            let cursorOpts = FindOptions(cursorType: .tailable)

            var cursor = try coll.find(options: cursorOpts)
            expect(try cursor.next()?.get()).to(beNil())
            // no documents matched initial query, so cursor is dead
            expect(cursor.isAlive).to(beFalse())
            // iterating iterating dead cursor should error
            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))

            // insert a doc so something matches initial query
            try coll.insertOne(doc1)
            cursor = try coll.find(options: cursorOpts)

            // for each doc we insert, check that it arrives in the cursor next,
            // and that the cursor is still alive afterward
            let checkNextResult: (Document) throws -> Void = { doc in
                let result = cursor.tryNext()
                expect(result).toNot(beNil())
                expect(try result?.get()).to(equal(doc))
                expect(cursor.isAlive).to(beTrue())
            }
            try checkNextResult(doc1)

            try coll.insertOne(doc2)
            try checkNextResult(doc2)

            try coll.insertOne(doc3)
            try checkNextResult(doc3)

            // no more docs, but should still be alive
            expect(try cursor.tryNext()?.get()).to(beNil())
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
            expect(try cursor.next()?.get()).to(throwError(expectedError))
            // cursor should be closed now that it errored
            expect(cursor.isAlive).to(beFalse())

            // iterating dead cursor should error
            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))
        }
    }

    func testNext() throws {
        try self.withTestNamespace { _, _, coll in
            // query empty collection
            var cursor = try coll.find()
            expect(cursor.next()).to(beNil())

            // insert a doc so something matches initial query
            try coll.insertOne(doc1)
            cursor = try coll.find()

            // next() returns a Result<Document, Error>?
            let result = cursor.next()
            expect(result).toNot(beNil())
            expect(try result?.get()).to(equal(doc1))

            expect(cursor.next()).to(beNil())
            expect(cursor.isAlive).to(beFalse())

            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))
        }
    }

    func testClose() throws {
        try self.withTestNamespace { _, _, coll in
            _ = try coll.insertMany([[:], [:], [:]])
            let cursor = try coll.find()
            expect(cursor.isAlive).to(beTrue())

            expect(cursor.next()).toNot(beNil())
            expect(cursor.isAlive).to(beTrue())

            cursor.close()
            expect(cursor.isAlive).to(beFalse())
            expect(try cursor.next()?.get()).to(throwError(errorType: LogicError.self))
        }

        let options = CreateCollectionOptions(capped: true, max: 3, size: 1000)
        try self.withTestNamespace(ns: self.getNamespace(suffix: "tail"), collectionOptions: options) { _, _, coll in
            let docs: [Document] = [["_id": 1], ["_id": 2], ["_id": 3]]
            _ = try coll.insertMany(docs)
            let cursor = try coll.find(options: FindOptions(cursorType: .tailable))
            expect(cursor.isAlive).to(beTrue())

            let queue = DispatchQueue(label: "tailable close")
            let allDocsLock = DispatchSemaphore(value: 1)

            var allDocs: [Document]?
            var allError: Error?
            queue.async {
                allDocsLock.wait()
                defer { allDocsLock.signal() }
                do {
                    allDocs = try cursor.all() // should block after 3 docs are found
                } catch {
                    allError = error
                }
            }

            // should be blocked on the cursor trying for more results.
            expect(allDocsLock.wait(timeout: DispatchTime.now() + 1)).to(equal(.timedOut))
            cursor.close() // close cursor while it's blocking

            // wait for allDocs to be updated
            expect(allDocsLock.wait(timeout: DispatchTime.now() + 0.25)).to(equal(.success))
            defer { allDocsLock.signal() }

            expect(allError).to(beNil())
            expect(allDocs).toNot(beNil())
            expect(allDocs).to(equal(docs))
        }
    }
}
