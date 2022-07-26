import MongoSwift
// swiftlint:disable duplicate_imports
@testable import class MongoSwift.ClientSession

struct EndSession: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        session.end()
        return .none
    }
}

struct UnifiedStartTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try session.startTransaction()
        return .none
    }
}

struct UnifiedCommitTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try session.commitTransaction()
        return .none
    }
}

struct UnifiedAbortTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try session.abortTransaction()
        return .none
    }
}
