@testable import MongoSwift

/// Enum encapsulating the possible results returned from CRUD operations.
enum TestOperationResult: Decodable, Equatable {
    /// Crud operation returns an int (e.g. `count`).
    case int(Int)

    /// Result of CRUD operations that return an array of `BSONValues` (e.g. `distinct`).
    case array([BSONValue])

    /// Result of CRUD operations that return a single `Document` (e.g. `findOneAndDelete`).
    case document(Document)

    /// Result of CRUD operations whose result can be represented by a `BulkWriteResult` (e.g. `InsertOne`).
    case bulkWrite(BulkWriteResult)

    public init?(from doc: Document?) {
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

    public init(from cursor: SyncMongoCursor<Document>) {
        self = .array(Array(cursor))
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
        } else if let array = try? [AnyBSONValue](from: decoder) {
            self = .array(array.map { $0.value })
        } else if let doc = try? Document(from: decoder) {
            self = .document(doc)
        } else {
            throw DecodingError.valueNotFound(TestOperationResult.self,
                                              DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "couldn't decode outcome")
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
            return lhsArray.bsonEquals(rhsArray)
        case let(.document(lhsDoc), .document(rhsDoc)):
            return lhsDoc.sortedEquals(rhsDoc)
        default:
            return false
        }
    }
}

/// Protocol for allowing conversion from different result types to `BulkWriteResult`.
/// This behavior is used to funnel the various CRUD results into the `.bulkWrite` `TestOperationResult` case.
protocol BulkWriteResultConvertible {
    var bulkResultValue: BulkWriteResult { get }
}

extension BulkWriteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult { return self }
}

extension InsertManyResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(insertedCount: self.insertedCount, insertedIds: self.insertedIds)
    }
}

extension InsertOneResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(insertedCount: 1, insertedIds: [0: self.insertedId])
    }
}

extension UpdateResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        var upsertedIds: [Int: BSONValue]?
        if let upsertedId = self.upsertedId {
            upsertedIds = [0: upsertedId]
        }

        return BulkWriteResult(matchedCount: self.matchedCount,
                               modifiedCount: self.modifiedCount,
                               upsertedCount: self.upsertedCount,
                               upsertedIds: upsertedIds)
    }
}

extension DeleteResult: BulkWriteResultConvertible {
    internal var bulkResultValue: BulkWriteResult {
        return BulkWriteResult(deletedCount: self.deletedCount)
    }
}
