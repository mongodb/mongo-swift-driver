import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

/// Enum encapsulating the possible results returned from test operations.
enum TestOperationResult: Decodable, Equatable, Matchable {
    /// Crud operation returns an int (e.g. `count`).
    case int(Int)

    /// Result of CRUD operations that return an array of `BSONValues` (e.g. `distinct`).
    case array([BSON])

    /// Result of CRUD operations that return a single `Document` (e.g. `findOneAndDelete`).
    case document(BSONDocument)

    /// Result of CRUD operations whose result can be represented by a `BulkWriteResult` (e.g. `InsertOne`).
    case bulkWrite(BulkWriteResult)

    /// Result of test operations that are expected to return an error
    /// (e.g. `MongoError.CommandError`, `MongoError.WriteError`).
    case error(ErrorResult)

    public init?(from doc: BSONDocument?) {
        guard let doc = doc else {
            return nil
        }
        self = .document(doc)
    }

    public init?(from result: BulkWriteResultConvertible?) {
        guard let result = result else {
            return nil
        }
        self = .bulkWrite(result.bulkResultValue)
    }

    public init<T: Codable>(from cursor: MongoCursor<T>) throws {
        let result = try cursor.all().map { BSON.document(try BSONEncoder().encode($0)) }
        self = .array(result)
    }

    public init<T: Codable>(from array: [T]) throws {
        self = try .array(array.map { .document(try BSONEncoder().encode($0)) })
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let insertOneResult = try? container.decode(InsertOneResult.self) {
            self = .bulkWrite(insertOneResult.bulkResultValue)
        } else if let updateResult = try? container.decode(UpdateResult.self), updateResult.upsertedID != nil {
            self = .bulkWrite(updateResult.bulkResultValue)
        } else if let bulkWriteResult = try? container.decode(BulkWriteResult.self) {
            self = .bulkWrite(bulkWriteResult)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let array = try? container.decode([BSON].self) {
            self = .array(array)
        } else if let error = try? container.decode(ErrorResult.self) {
            self = .error(error)
        } else if let doc = try? container.decode(BSONDocument.self) {
            self = .document(doc)
        } else {
            throw DecodingError.valueNotFound(
                TestOperationResult.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "couldn't decode outcome"
                )
            )
        }
    }

    internal static func == (lhs: TestOperationResult, rhs: TestOperationResult) -> Bool {
        switch (lhs, rhs) {
        case let (.bulkWrite(lhsBw), .bulkWrite(rhsBw)):
            return lhsBw == rhsBw
        case let (.int(lhsInt), .int(rhsInt)):
            return lhsInt == rhsInt
        case let (.array(lhsArray), .array(rhsArray)):
            return lhsArray == rhsArray
        case let (.document(lhsDoc), .document(rhsDoc)):
            return lhsDoc.sortedEquals(rhsDoc)
        case let (.error(lhsErr), .error(rhsErr)):
            return lhsErr == rhsErr
        default:
            return false
        }
    }

    internal func contentMatches(expected: TestOperationResult) -> Bool {
        switch (self, expected) {
        case let (.bulkWrite(bw), .bulkWrite(expectedBw)):
            return bw.matches(expected: expectedBw)
        case let (.int(int), .int(expectedInt)):
            return int.matches(expected: expectedInt)
        case let (.array(array), .array(expectedArray)):
            return array.matches(expected: expectedArray)
        case let (.document(doc), .document(expectedDoc)):
            return doc.matches(expected: expectedDoc)
        case (.error, .error):
            return false
        default:
            return false
        }
    }
}

extension BulkWriteResult: Matchable {}

/// Protocol for allowing conversion from different result types to `BulkWriteResult`.
/// This behavior is used to funnel the various CRUD results into the `.bulkWrite` `TestOperationResult` case.
protocol BulkWriteResultConvertible {
    var bulkResultValue: BulkWriteResult { get }
}

extension BulkWriteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult { self }
}

extension InsertManyResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        BulkWriteResult.new(insertedCount: self.insertedCount, insertedIDs: self.insertedIDs)
    }
}

extension InsertOneResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        BulkWriteResult.new(insertedCount: 1, insertedIDs: [0: self.insertedID])
    }
}

extension UpdateResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        var upsertedIDs: [Int: BSON]?
        if let upsertedID = self.upsertedID {
            upsertedIDs = [0: upsertedID]
        }

        return BulkWriteResult.new(
            matchedCount: self.matchedCount,
            modifiedCount: self.modifiedCount,
            upsertedCount: self.upsertedCount,
            upsertedIDs: upsertedIDs
        )
    }
}

extension DeleteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        BulkWriteResult.new(deletedCount: self.deletedCount)
    }
}

struct ErrorResult: Equatable, Decodable {
    internal var errorContains: String?

    internal var errorCodeName: String?

    internal var errorLabelsContain: [String]?

    internal var errorLabelsOmit: [String]?

    private enum CodingKeys: CodingKey {
        case errorContains, errorCodeName, errorLabelsContain, errorLabelsOmit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // None of the error keys must be present themselves, but at least one must.
        guard !container.allKeys.isEmpty else {
            throw DecodingError.valueNotFound(
                ErrorResult.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "No results found"
                )
            )
        }

        self.errorContains = try container.decodeIfPresent(String.self, forKey: .errorContains)
        self.errorCodeName = try container.decodeIfPresent(String.self, forKey: .errorCodeName)
        self.errorLabelsContain = try container.decodeIfPresent([String].self, forKey: .errorLabelsContain)
        self.errorLabelsOmit = try container.decodeIfPresent([String].self, forKey: .errorLabelsOmit)
    }

    public func checkErrorResult(_ error: Error, description: String) {
        self.checkErrorContains(error, description: description)
        self.checkCodeName(error, description: description)
        self.checkErrorLabels(error, description: description)
    }

    private func checkErrorContains(_ error: Error, description: String) {
        if let errorContains = self.errorContains?.lowercased() {
            expect(error.localizedDescription.lowercased()).to(contain(errorContains), description: description)
        }
    }

    private func checkCodeName(_ error: Error, description: String) {
        // TODO: can remove `equal("")` references once SERVER-36755 is resolved
        if let errorCodeName = self.errorCodeName {
            if let commandError = error as? MongoError.CommandError {
                expect(commandError.codeName)
                    .to(satisfyAnyOf(equal(errorCodeName), equal("")), description: description)
            } else if let writeError = error as? MongoError.WriteError {
                if let writeFailure = writeError.writeFailure {
                    expect(writeFailure.codeName)
                        .to(satisfyAnyOf(equal(errorCodeName), equal("")), description: description)
                }
                if let writeConcernFailure = writeError.writeConcernFailure {
                    expect(writeConcernFailure.codeName)
                        .to(satisfyAnyOf(equal(errorCodeName), equal("")), description: description)
                }
            } else if let bulkWriteError = error as? MongoError.BulkWriteError {
                if let writeFailures = bulkWriteError.writeFailures {
                    for writeFailure in writeFailures {
                        expect(writeFailure.codeName)
                            .to(satisfyAnyOf(equal(errorCodeName), equal("")), description: description)
                    }
                }
                if let writeConcernFailure = bulkWriteError.writeConcernFailure {
                    expect(writeConcernFailure.codeName)
                        .to(satisfyAnyOf(equal(errorCodeName), equal("")), description: description)
                }
            } else {
                XCTFail("\(description): \(error) does not contain codeName")
            }
        }
    }

    private func checkErrorLabels(_ error: Error, description: String) {
        if let errorLabelsContain = self.errorLabelsContain {
            guard let labeledError = error as? MongoLabeledError else {
                XCTFail("\(description): \(error) does not contain errorLabels")
                return
            }
            for label in errorLabelsContain {
                expect(labeledError.hasErrorLabel(label)).to(beTrue(), description: description)
            }
        }

        if let errorLabelsOmit = self.errorLabelsOmit {
            guard let labeledError = error as? MongoLabeledError else {
                XCTFail("\(description): \(error) does not contain errorLabels")
                return
            }
            guard let errorLabels = labeledError.errorLabels else {
                return
            }
            for label in errorLabelsOmit {
                expect(errorLabels).toNot(contain(label), description: description)
            }
        }
    }
}
