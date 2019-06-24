import Foundation
@testable import MongoSwift
import Nimble
import XCTest

/// Struct representing the contents of a collection after a spec test has been run.
internal struct CollectionTestInfo: Decodable {
    /// An optional name specifying a collection whose documents match the `data` field of this struct.
    /// If nil, whatever collection used in the test should be used instead.
    let name: String?

    /// The documents found in the collection.
    let data: [Document]
}

/// Struct representing an "outcome" defined in a spec test.
internal struct TestOutcome: Decodable {
    /// Whether an error is expected or not.
    let error: Bool?

    /// The expected result of running the operation associated with this test.
    let result: TestOperationResult?

    /// The expected state of the collection at the end of the test.
    let collection: CollectionTestInfo
}

/// Protocol defining the behavior of an individual spec test.
protocol SpecTest {
    var description: String { get }
    var outcome: TestOutcome { get }
    var operation: AnyTestOperation { get }

    /// Runs the operation with the given context and performs assertions on the result based upon the expected outcome.
    func run(client: MongoClient,
             db: MongoDatabase,
             collection: MongoCollection<Document>,
             session: ClientSession) throws
}

/// Default implementation of a test execution.
extension SpecTest {
    internal func run(client: MongoClient,
                      db: MongoDatabase,
                      collection: MongoCollection<Document>,
                      session: ClientSession?) throws {
        var result: TestOperationResult?
        var seenError: Error?
        do {
            result = try self.operation.op.execute(
                    client: client,
                    database: db,
                    collection: collection,
                    session: session)
        } catch {
            if case let ServerError.bulkWriteError(_, _, bulkResult, _) = error {
                result = TestOperationResult(from: bulkResult)
            }
            seenError = error
        }

        if self.outcome.error ?? false {
            expect(seenError).toNot(beNil(), description: self.description)
        } else {
            expect(seenError).to(beNil(), description: self.description)
        }

        if let expectedResult = self.outcome.result {
            expect(result).toNot(beNil(), description: self.description)
            expect(result).to(equal(expectedResult), description: self.description)
        }
        let verifyColl = db.collection(self.outcome.collection.name ?? collection.name)
        let foundDocs = try Array(verifyColl.find())
        expect(foundDocs.count).to(equal(self.outcome.collection.data.count))
        zip(foundDocs, self.outcome.collection.data).forEach {
            expect($0).to(sortedEqual($1), description: self.description)
        }
    }
}
