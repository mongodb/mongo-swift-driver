import Foundation
@testable import MongoSwift

extension RuntimeError: Equatable {
    public static func == (lhs: RuntimeError, rhs: RuntimeError) -> Bool {
        switch (lhs, rhs) {
        case (.internalError(message: _), .internalError(message: _)),
             (.authenticationError(message: _), .authenticationError(message: _)),
             (.compatibilityError(message: _), .compatibilityError(message: _)):
            return true
        case let (.connectionError(message: _, errorLabels: lhsLabels),
                  .connectionError(message: _, errorLabels: rhsLabels)):
            return sortAndCompareOptionalArrays(lhs: lhsLabels, rhs: rhsLabels, cmp: { $0 < $1 })
        default:
            return false
        }
    }
}

extension ServerError: Equatable {
    public static func == (lhs: ServerError, rhs: ServerError) -> Bool {
        switch (lhs, rhs) {
        case let (.commandError(code: lhsCode, codeName: _, message: _, errorLabels: lhsErrorLabels),
                  .commandError(code: rhsCode, codeName: _, message: _, errorLabels: rhsErrorLabels)):
            return lhsCode == rhsCode
                    && sortAndCompareOptionalArrays(lhs: lhsErrorLabels, rhs: rhsErrorLabels, cmp: { $0 < $1 })
        case let (.writeError(writeError: lhsWriteError, writeConcernError: lhsWCError, errorLabels: lhsErrorLabels),
                  .writeError(writeError: rhsWriteError, writeConcernError: rhsWCError, errorLabels: rhsErrorLabels)):
            return lhsWriteError == rhsWriteError
                    && lhsWCError == rhsWCError
                    && sortAndCompareOptionalArrays(lhs: lhsErrorLabels, rhs: rhsErrorLabels, cmp: { $0 < $1 })
        case let (.bulkWriteError(writeErrors: lhsWriteErrors,
                                  writeConcernError: lhsWCError,
                                  otherError: lhsOther,
                                  result: lhsResult,
                                  errorLabels: lhsErrorLabels),
                  .bulkWriteError(writeErrors: rhsWriteErrors,
                                  writeConcernError: rhsWCError,
                                  otherError: rhsOther,
                                  result: rhsResult,
                                  errorLabels: rhsErrorLabels)):
            let cmp = { (l: BulkWriteError, r: BulkWriteError) in l.index < r.index }

            return sortAndCompareOptionalArrays(lhs: lhsWriteErrors, rhs: rhsWriteErrors, cmp: cmp)
                    && lhsWCError == rhsWCError
                    && sortAndCompareOptionalArrays(lhs: lhsErrorLabels, rhs: rhsErrorLabels, cmp: { $0 < $1 })
                    && lhsResult == rhsResult
                    && lhsOther?.localizedDescription == rhsOther?.localizedDescription
        default:
            return false
        }
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

extension UserError: Equatable {
    public static func == (lhs: UserError, rhs: UserError) -> Bool {
        switch (lhs, rhs) {
        case (.logicError(message: _), .logicError(message: _)),
             (.invalidArgumentError(message: _), .invalidArgumentError(message: _)):
            return true
        default:
            return false
        }
    }
}

extension WriteError: Equatable {
    public static func == (lhs: WriteError, rhs: WriteError) -> Bool {
        return lhs.code == rhs.code
    }
}

extension BulkWriteError: Equatable {
    public static func == (lhs: BulkWriteError, rhs: BulkWriteError) -> Bool {
        return lhs.code == rhs.code && lhs.index == rhs.index
    }
}

extension WriteConcernError: Equatable {
    public static func == (lhs: WriteConcernError, rhs: WriteConcernError) -> Bool {
        return lhs.code == rhs.code && lhs.details == rhs.details
    }
}

/// Private function for sorting, then comparing two optional arrays.
/// TODO: remove this function and just use optional chaining once we drop Swift 4.0 support (SWIFT-283)
private func sortAndCompareOptionalArrays<T: Equatable>(lhs: [T]?, rhs: [T]?, cmp: (T, T) -> Bool) -> Bool {
    guard let lhsArr = lhs, let rhsArr = rhs else {
        return lhs == nil && rhs == nil
    }
    return lhsArr.sorted(by: cmp) == rhsArr.sorted(by: cmp)
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
