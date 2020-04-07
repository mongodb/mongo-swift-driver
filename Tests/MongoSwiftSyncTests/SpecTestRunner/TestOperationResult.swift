import MongoSwiftSync
import Nimble
import TestsCommon

/// Enum encapsulating the possible results returned from test operations.
enum TestOperationResult: Decodable, Equatable, Matchable {
    /// Crud operation returns an int (e.g. `count`).
    case int(Int)

    /// Result of CRUD operations that return an array of `BSONValues` (e.g. `distinct`).
    case array([BSON])

    /// Result of CRUD operations that return a single `Document` (e.g. `findOneAndDelete`).
    case document(Document)

    /// Result of CRUD operations whose result can be represented by a `BulkWriteResult` (e.g. `InsertOne`).
    case bulkWrite(BulkWriteResult)

    /// Result of test operations that are expected to return an error (e.g. `CommandError`, `WriteError`).
    case error(ErrorResult)

    public init?(from doc: Document?) {
        guard let doc = doc else {
            return nil
        }
        if !ErrorResult.errorKeys.isDisjoint(with: doc.keys) {
            self = .error(ErrorResult(from: doc))
        } else {
            self = .document(doc)
        }
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
        if let insertOneResult = try? InsertOneResult(from: decoder) {
            self = .bulkWrite(insertOneResult.bulkResultValue)
        } else if let updateResult = try? UpdateResult(from: decoder), updateResult.upsertedId != nil {
            self = .bulkWrite(updateResult.bulkResultValue)
        } else if let bulkWriteResult = try? BulkWriteResult(from: decoder) {
            self = .bulkWrite(bulkWriteResult)
        } else if let int = try? Int(from: decoder) {
            self = .int(int)
        } else if let array = try? [BSON](from: decoder) {
            self = .array(array)
        } else if let doc = try? Document(from: decoder) {
            if !ErrorResult.errorKeys.isDisjoint(with: doc.keys) {
                self = .error(ErrorResult(from: doc))
            } else {
                self = .document(doc)
            }
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
        case let (.error(error), .error(expectedError)):
            return error.matches(expected: expectedError)
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
        BulkWriteResult.new(insertedCount: self.insertedCount, insertedIds: self.insertedIds)
    }
}

extension InsertOneResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        BulkWriteResult.new(insertedCount: 1, insertedIds: [0: self.insertedId])
    }
}

extension UpdateResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        var upsertedIds: [Int: BSON]?
        if let upsertedId = self.upsertedId {
            upsertedIds = [0: upsertedId]
        }

        return BulkWriteResult.new(
            matchedCount: self.matchedCount,
            modifiedCount: self.modifiedCount,
            upsertedCount: self.upsertedCount,
            upsertedIds: upsertedIds
        )
    }
}

extension DeleteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        BulkWriteResult.new(deletedCount: self.deletedCount)
    }
}

struct ErrorResult: Equatable, Matchable {
    internal static let errorKeys: Set = ["errorContains", "errorCodeName", "errorLabelsContain", "errorLabelsOmit"]

    internal var errorContains: String?

    internal var errorCodeName: String?

    internal var errorLabelsContain: [String]?

    internal var errorLabelsOmit: [String]?

    public init(from doc: Document) {
        let errorLabelsContain = doc["errorLabelsContain"]?.arrayValue?.compactMap { $0.stringValue }
        let errorLabelsOmit = doc["errorLabelsOmit"]?.arrayValue?.compactMap { $0.stringValue }

        self.errorContains = doc["errorContains"]?.stringValue
        self.errorCodeName = doc["errorCodeName"]?.stringValue
        self.errorLabelsContain = errorLabelsContain?.sorted()
        self.errorLabelsOmit = errorLabelsOmit?.sorted()
    }

    internal static func == (lhs: ErrorResult, rhs: ErrorResult) -> Bool {
        lhs.errorContains == rhs.errorContains &&
            lhs.errorCodeName == rhs.errorCodeName &&
            lhs.errorLabelsContain == rhs.errorLabelsContain &&
            lhs.errorLabelsOmit == rhs.errorLabelsOmit
    }

    public func checkErrorResult(_ error: Error) throws {
        if let commandError = error as? CommandError {
            try self.checkCommandError(commandError)
        } else if let writeError = error as? WriteError {
            try self.checkWriteError(writeError)
        } else if let bulkWriteError = error as? BulkWriteError {
            try self.checkBulkWriteError(bulkWriteError)
        } else if let logicError = error as? LogicError {
            try self.checkLogicError(logicError)
        } else if let invalidArgumentError = error as? InvalidArgumentError {
            try self.checkInvalidArgumentError(invalidArgumentError)
        } else if let connectionError = error as? ConnectionError {
            try self.checkConnectionError(connectionError)
        } else {
            throw TestError(message: "checked ErrorResult with unhandled error \(error)")
        }
    }

    internal func checkErrorContains(errorDescription: String) throws {
        if let errorContains = self.errorContains {
            expect(errorDescription.lowercased()).to(contain(errorContains.lowercased()))
        }
    }

    internal func checkCodeName(codeName: String?) throws {
        if let errorCodeName = self.errorCodeName, let codeName = codeName, !codeName.isEmpty {
            expect(codeName).to(equal(errorCodeName))
        }
    }

    internal func checkErrorLabels(errorLabels: [String]?) throws {
        // `configureFailPoint` command correctly handles error labels in MongoDB v4.3.1+ (see SERVER-43941).
        // Do not check the "RetryableWriteError" error label until the spec test requirements are updated.
        let skippedErrorLabels = ["RetryableWriteError"]

        if let errorLabelsContain = self.errorLabelsContain, let errorLabels = errorLabels {
            errorLabelsContain.forEach { label in
                if !skippedErrorLabels.contains(label) {
                    expect(errorLabels).to(contain(label))
                }
            }
        }
        if let errorLabelsOmit = self.errorLabelsOmit, let errorLabels = errorLabels {
            errorLabelsOmit.forEach { label in
                expect(errorLabels).toNot(contain(label))
            }
        }
    }

    internal func checkCommandError(_ error: CommandError) throws {
        try self.checkErrorContains(errorDescription: error.message)
        try self.checkCodeName(codeName: error.codeName)
        try self.checkErrorLabels(errorLabels: error.errorLabels)
    }

    internal func checkWriteError(_ error: WriteError) throws {
        if let writeFailure = error.writeFailure {
            try self.checkErrorContains(errorDescription: writeFailure.message)
            try self.checkCodeName(codeName: writeFailure.codeName)
        }
        if let writeConcernFailure = error.writeConcernFailure {
            try self.checkErrorContains(errorDescription: writeConcernFailure.message)
            try self.checkCodeName(codeName: writeConcernFailure.codeName)
        }
        try self.checkErrorLabels(errorLabels: error.errorLabels)
    }

    internal func checkBulkWriteError(_ error: BulkWriteError) throws {
        if let writeFailures = error.writeFailures {
            try writeFailures.forEach { writeFailure in
                try checkErrorContains(errorDescription: writeFailure.message)
                try checkCodeName(codeName: writeFailure.codeName)
            }
        }
        if let writeConcernFailure = error.writeConcernFailure {
            try self.checkErrorContains(errorDescription: writeConcernFailure.message)
            try self.checkCodeName(codeName: writeConcernFailure.codeName)
        }
    }

    internal func checkLogicError(_ error: LogicError) throws {
        try self.checkErrorContains(errorDescription: error.errorDescription)
        // `LogicError` does not have error labels or a code name so there is no need to check them.
    }

    internal func checkInvalidArgumentError(_ error: InvalidArgumentError) throws {
        try self.checkErrorContains(errorDescription: error.errorDescription)
        // `InvalidArgumentError` does not have error labels or a code name so there is no need to check them.
    }

    internal func checkConnectionError(_ error: ConnectionError) throws {
        try self.checkErrorContains(errorDescription: error.message)
        try self.checkErrorLabels(errorLabels: error.errorLabels)
        // `ConnectionError` does not have a code name so there is no need to check it.
    }
}
