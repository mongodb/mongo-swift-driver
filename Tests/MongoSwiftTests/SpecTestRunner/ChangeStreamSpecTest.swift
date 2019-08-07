import mongoc
@testable import MongoSwift
import Nimble
import XCTest

internal struct TestResult: Decodable {
    /// Describes an error received during the test
    let error: ChangeStreamTestError?

    /// An Extended JSON array of documents expected to be received from the changeStream
    let success: [ChangeStreamTestEventDocument]?
}

internal struct ChangeStreamTestError: Decodable {
    let code: Int

    let errorLabels: [String]?
}

internal struct ChangeStreamTestEventDocument: Codable, Equatable {
    let operationType: String

    let ns: MongoNamespace?

    let fullDocument: Document?
}

extension ChangeStreamTestEventDocument {
    public static func == (lhs: ChangeStreamTestEventDocument, rhs: ChangeStreamTestEventDocument) -> Bool {
        let lhsFullDoc = lhs.fullDocument?.filter { elem in
            let key = elem.key
            return key != "_id"
        }

        let rhsFullDoc = rhs.fullDocument?.filter { elem in
            let key = elem.key
            return key != "_id"
        }

        return lhsFullDoc == rhsFullDoc && lhs.ns == rhs.ns && lhs.operationType == rhs.operationType
    }
}

internal protocol ChangeStreamSpecTest: Decodable {
    var description: String { get }
    var operations: [AnyTestOperation] { get }
    var result: TestResult { get }

    func run(client: MongoClient, db1: MongoDatabase, db2: MongoDatabase, seenError: Error?, changeStream: ChangeStream<ChangeStreamTestEventDocument>?) throws
}

extension ChangeStreamSpecTest {
    func run(client: MongoClient,
             db1: MongoDatabase,
             db2: MongoDatabase,
             seenError: Error?,
             changeStream: ChangeStream<ChangeStreamTestEventDocument>?) throws {
        var seenError = seenError
        for operation in self.operations {
            guard let dbName = operation.database else {
                return
            }

            guard let collName = operation.collection else {
                return
            }

            var db: MongoDatabase
            var coll: MongoCollection<Document>
            switch dbName {
            case db1.name:
                coll = db1.collection(collName)
                db = db1
            case db2.name:
                coll = db2.collection(collName)
                db = db2
            default:
                throw UserError.logicError(message: "unsupported database name \(dbName)")
            }

            do {
                try operation.op.execute(client: client,
                                         database: db,
                                         collection: coll,
                                         session: nil)
            } catch {
                seenError = error
            }
        }
        // If there was an error
        if seenError != nil {
            // assert errors match expected errors
            assertErrors(seenError: seenError)
        } else {
            // assert change doc match expected change doc
            assertSuccess(changeStream: changeStream)
        }
     }

     private func assertErrors(seenError: Error?) {
        // Assert that an error was expected for the self.
        expect(self.result.error).toNot(beNil())
        // Assert that the error MATCHES result.error
        if let errorCode = self.result.error?.code {
            expect(seenError as? ServerError).to(equal(ServerError
                                                    .commandError(code: errorCode,
                                                                  codeName: "",
                                                                  message: "",
                                                                  errorLabels: self.result.error?
                                                                                          .errorLabels)))
        }
    }

    private func assertSuccess(changeStream: ChangeStream<ChangeStreamTestEventDocument>?) {
        // Assert that no error was expected for the test
        expect(self.result.error).to(beNil())
        // Assert that the changes received from changeStream MATCH the results in result.success
        if let changeStream = changeStream {
            if let expectedChange = self.result.success {
                for i in 0...expectedChange.count - 1 {
                    let expectedChange = expectedChange[i]
                    if let change = changeStream.next() {
                        expect(change).to(equal(expectedChange))
                    }
                }
            }
        }
    }
}
