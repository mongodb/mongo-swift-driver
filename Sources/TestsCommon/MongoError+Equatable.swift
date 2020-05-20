import Foundation
import MongoSwift

extension ConnectionError: Equatable {
    public static func == (lhs: ConnectionError, rhs: ConnectionError) -> Bool {
        lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension CommandError: Equatable {
    public static func == (lhs: CommandError, rhs: CommandError) -> Bool {
        lhs.code == rhs.code && lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension WriteError: Equatable {
    public static func == (lhs: WriteError, rhs: WriteError) -> Bool {
        lhs.writeFailure == rhs.writeFailure &&
            lhs.writeConcernFailure == rhs.writeConcernFailure &&
            lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension BulkWriteError: Equatable {
    public static func == (lhs: BulkWriteError, rhs: BulkWriteError) -> Bool {
        let cmp = { (lhs: BulkWriteFailure, rhs: BulkWriteFailure) in
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

extension WriteFailure: Equatable {
    public static func == (lhs: WriteFailure, rhs: WriteFailure) -> Bool {
        lhs.code == rhs.code
    }
}

extension BulkWriteFailure: Equatable {
    public static func == (lhs: BulkWriteFailure, rhs: BulkWriteFailure) -> Bool {
        lhs.code == rhs.code && lhs.index == rhs.index
    }
}

extension WriteConcernFailure: Equatable {
    public static func == (lhs: WriteConcernFailure, rhs: WriteConcernFailure) -> Bool {
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
