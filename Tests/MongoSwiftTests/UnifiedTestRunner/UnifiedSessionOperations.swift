import MongoSwift
// swiftlint:disable duplicate_imports
@testable import class MongoSwift.ClientSession

struct EndSession: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        // Method doesnt exist for async/await bc if concurrency is available, the method is auto-called with deinit
        session.end()
        return .none
    }
}

struct UnifiedStartTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.startTransaction()
        return .none
    }
}

struct UnifiedCommitTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.commitTransaction()
        return .none
    }
}

struct UnifiedAbortTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.abortTransaction()
        return .none
    }
}
