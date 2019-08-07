import mongoc
@testable import MongoSwift
import Nimble
import XCTest

internal struct ChangeStreamAnyTestOperation: Decodable {
    let anyTestOperation: AnyTestOperation

    let database: String?

    let collection: String?

    private enum CodingKeys: String, CodingKey {
        case database, collection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.database = try container.decodeIfPresent(String.self, forKey: .database)
        self.collection = try container.decodeIfPresent(String.self, forKey: .collection)
        self.anyTestOperation = try AnyTestOperation(from: decoder)
    }
}

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
    var operations: [ChangeStreamAnyTestOperation] { get }
    var result: TestResult { get }

    func run(client: MongoClient,
             seenError: Error?,
             changeStream: ChangeStream<ChangeStreamTestEventDocument>?) throws
}

extension ChangeStreamSpecTest {
    func run(client: MongoClient,
             seenError: Error?,
             changeStream: ChangeStream<ChangeStreamTestEventDocument>?) throws {
        var seenError = seenError
        for operation in self.operations {
            guard let dbName = operation.database else {
                print("The database name for running the operation is missing.")
                return
            }

            guard let collName = operation.collection else {
                print("The collection name for running the operation is missing.")
                return
            }

            let db = client.db(dbName)
            let coll = db.collection(collName)

            do {
                try operation.anyTestOperation.op.execute(client: client,
                                                          database: db,
                                                          collection: coll,
                                                          session: nil)
            } catch {
                seenError = error
            }
        }

        if seenError != nil {
            // assert errors match expected errors
            assertError(seenError: seenError)
        } else {
            // assert change doc match expected change doc
            assertSuccess(changeStream: changeStream)
        }
     }

     private func assertError(seenError: Error?) {
        // assert that an error was expected for the test
        expect(self.result.error).toNot(beNil())
        // assert that the error matches expected error
        if let expectedErrorCode = self.result.error?.code {
            expect(seenError as? ServerError).to(equal(ServerError
                                                    .commandError(code: expectedErrorCode,
                                                                  codeName: "",
                                                                  message: "",
                                                                  errorLabels: self.result.error?
                                                                                          .errorLabels)))
        }
    }

    private func assertSuccess(changeStream: ChangeStream<ChangeStreamTestEventDocument>?) {
        // assert that no error was expected for the test
        expect(self.result.error).to(beNil())
        // assert that the changes received from changeStream MATCH the results in result.success
        if let changeStream = changeStream, let expectedChanges = self.result.success {
            for expectedChange in expectedChanges {
                if let change = changeStream.next() {
                    expect(change).to(equal(expectedChange))
                }
            }
        }
    }
}
