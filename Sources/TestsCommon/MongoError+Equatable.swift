import Foundation
import MongoSwift

extension InternalError: Equatable {
    public static func == (_: InternalError, _: InternalError) -> Bool {
        return true
    }
}

extension AuthenticationError: Equatable {
    public static func == (_: AuthenticationError, _: AuthenticationError) -> Bool {
        return true
    }
}

extension CompatibilityError: Equatable {
    public static func == (_: CompatibilityError, _: CompatibilityError) -> Bool {
        return true
    }
}

extension ConnectionError: Equatable {
    public static func == (lhs: ConnectionError, rhs: ConnectionError) -> Bool {
        return lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension ServerSelectionError: Equatable {
    public static func == (_: ServerSelectionError, _: ServerSelectionError) -> Bool {
        return true
    }
}

extension CommandError: Equatable {
    public static func == (lhs: CommandError, rhs: CommandError) -> Bool {
        return lhs.code == rhs.code && lhs.errorLabels?.sorted() == rhs.errorLabels?.sorted()
    }
}

extension WriteError: Equatable {
    public static func == (lhs: WriteError, rhs: WriteError) -> Bool {
        return lhs.writeFailure == rhs.writeFailure &&
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
        return lhs.insertedIds == rhs.insertedIds
            && lhs.upsertedIds == rhs.upsertedIds
            && lhs.upsertedCount == rhs.upsertedCount
            && lhs.modifiedCount == rhs.modifiedCount
            && lhs.matchedCount == rhs.matchedCount
            && lhs.insertedCount == rhs.insertedCount
    }
}

extension LogicError: Equatable {
    public static func == (_: LogicError, _: LogicError) -> Bool {
        return true
    }
}

extension InvalidArgumentError: Equatable {
    public static func == (_: InvalidArgumentError, _: InvalidArgumentError) -> Bool {
        return true
    }
}

extension WriteFailure: Equatable {
    public static func == (lhs: WriteFailure, rhs: WriteFailure) -> Bool {
        return lhs.code == rhs.code
    }
}

extension BulkWriteFailure: Equatable {
    public static func == (lhs: BulkWriteFailure, rhs: BulkWriteFailure) -> Bool {
        return lhs.code == rhs.code && lhs.index == rhs.index
    }
}

extension WriteConcernFailure: Equatable {
    public static func == (lhs: WriteConcernFailure, rhs: WriteConcernFailure) -> Bool {
        return lhs.code == rhs.code && lhs.details == rhs.details
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
