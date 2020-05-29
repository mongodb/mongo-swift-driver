import Foundation
import MongoSwift

extension MongoError.ConnectionError: Equatable {
    public static func == (lhs: MongoError.ConnectionError, rhs: MongoError.ConnectionError) -> Bool {
        lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension MongoError.CommandError: Equatable {
    public static func == (lhs: MongoError.CommandError, rhs: MongoError.CommandError) -> Bool {
        lhs.code == rhs.code && lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension MongoError.WriteError: Equatable {
    public static func == (lhs: MongoError.WriteError, rhs: MongoError.WriteError) -> Bool {
        lhs.writeFailure == rhs.writeFailure &&
            lhs.writeConcernFailure == rhs.writeConcernFailure &&
            lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension MongoError.BulkWriteError: Equatable {
    public static func == (lhs: MongoError.BulkWriteError, rhs: MongoError.BulkWriteError) -> Bool {
        let cmp = { (lhs: MongoError.BulkWriteFailure, rhs: MongoError.BulkWriteFailure) in
            lhs.index < rhs.index
        }

        return lhs.writeFailures?.sorted(by: cmp) == rhs.writeFailures?.sorted(by: cmp) &&
            lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted() &&
            lhs.result == rhs.result &&
            rhs.otherError?.localizedDescription == rhs.otherError?.localizedDescription
    }
}

extension BulkWriteResult: Equatable {
    public static func == (lhs: BulkWriteResult, rhs: BulkWriteResult) -> Bool {
        lhs.insertedIDs == rhs.insertedIDs
            && lhs.upsertedIDs == rhs.upsertedIDs
            && lhs.upsertedCount == rhs.upsertedCount
            && lhs.modifiedCount == rhs.modifiedCount
            && lhs.matchedCount == rhs.matchedCount
            && lhs.insertedCount == rhs.insertedCount
    }
}

extension MongoError.WriteFailure: Equatable {
    public static func == (lhs: MongoError.WriteFailure, rhs: MongoError.WriteFailure) -> Bool {
        lhs.code == rhs.code
    }
}

extension MongoError.BulkWriteFailure: Equatable {
    public static func == (lhs: MongoError.BulkWriteFailure, rhs: MongoError.BulkWriteFailure) -> Bool {
        lhs.code == rhs.code && lhs.index == rhs.index
    }
}

extension MongoError.WriteConcernFailure: Equatable {
    public static func == (lhs: MongoError.WriteConcernFailure, rhs: MongoError.WriteConcernFailure) -> Bool {
        lhs.code == rhs.code
    }
}

extension DecodingError: Equatable {
    public static func == (lhs: DecodingError, rhs: DecodingError) -> Bool {
        switch (lhs, rhs) {
        case (.typeMismatch, .typeMismatch),
             (.dataCorrupted, .dataCorrupted),
             (.keyNotFound, .keyNotFound),
             (.valueNotFound, .valueNotFound):
            return true
        default:
            return false
        }
    }
}
