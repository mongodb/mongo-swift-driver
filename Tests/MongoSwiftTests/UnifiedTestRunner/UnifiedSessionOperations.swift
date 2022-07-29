#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift

@available(macOS 10.15, *)
struct EndSession: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        // Method doesnt exist for async/await bc if concurrency is available, the method is auto-called with deinit
        _ = session.end()
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedStartTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.startTransaction()
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedCommitTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.commitTransaction()
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAbortTransaction: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(from: object).asSession()
        try await session.abortTransaction()
        return .none
    }
}
#endif
