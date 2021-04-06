import Foundation
import MongoSwiftSync
import TestsCommon

/// Protocol which all operations supported by the unified test runner conform to.
protocol UnifiedOperationProtocol: Decodable {
    /// Set of supported arguments for the operation.
    static var knownArguments: Set<String> { get }

    /// Executes this operation on the provided object, using the provided context.
    func execute(on object: UnifiedOperation.Object, context: Context) throws -> UnifiedOperationResult
}

enum UnifiedOperationResult {
    case changeStream(ChangeStream<BSONDocument>)
    case bson(BSON)
    case rootDocument(BSONDocument)
    case rootDocumentArray([BSONDocument])
    case none

    func asEntity() throws -> Entity {
        switch self {
        case let .changeStream(cs):
            return .changeStream(cs)
        case let .bson(bson):
            return .bson(bson)
        case let .rootDocument(document):
            return .bson(.document(document))
        case let .rootDocumentArray(arr):
            return .bson(.array(arr.map { .document($0) }))
        case .none:
            throw TestError(message: "Cannot convert result type .none to an entity")
        }
    }
}

struct UnifiedOperation: Decodable {
    /// Represents an object on which to perform an operation.
    enum Object: RawRepresentable, Decodable {
        /// Used for special test operations.
        case testRunner
        /// An entity name e.g. "client0".
        case entity(String)

        public var rawValue: String {
            switch self {
            case .testRunner:
                return "testRunner"
            case let .entity(s):
                return s
            }
        }

        public init(rawValue: String) {
            switch rawValue {
            case "testRunner":
                self = .testRunner
            default:
                self = .entity(rawValue)
            }
        }

        func asEntityId() throws -> String {
            guard case let .entity(id) = self else {
                throw TestError(message: "Expected object to be an entity, but got testRunner")
            }
            return id
        }
    }

    /// Object on which to perform the operation.
    let object: Object

    /// Specific operation to execute.
    let operation: UnifiedOperationProtocol

    /// The name of the operation.
    let name: String

    /// Expected result of the operation.
    let expectedResult: ExpectedOperationResult?

    func executeAndCheckResult(context: Context) throws {
        do {
            let actualResult = try self.operation.execute(on: self.object, context: context)
            switch self.expectedResult {
            case .error:
                throw TestError(
                    message: "Expected operation to error, but got result: \(actualResult). Path: \(context.path)"
                )
            case let .result(expected, saveAsEntity):
                if let entityId = saveAsEntity {
                    context.entities[entityId] = try actualResult.asEntity()
                }
                if let expected = expected {
                    try context.withPushedElt("expectResult") {
                        try actualResult.matches(expected: expected, context: context)
                    }
                }
            case .none:
                return
            }
        } catch {
            guard case let .error(expectedError) = self.expectedResult else {
                throw TestError(
                    message: "Expected operation to succeed, but got error: \(error). Path: \(context.path)"
                )
            }

            guard let mongoError = error as? MongoErrorProtocol else {
                throw TestError(
                    message: "Expected operation to throw an error conforming to MongoErrorProtocol, but got \(error)"
                )
            }

            try context.withPushedElt("expectError") {
                try mongoError.matches(expectedError, context: context)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, object, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        switch self.name {
        case "abortTransaction":
            self.operation = UnifiedAbortTransaction()
        case "aggregate":
            self.operation = try container.decode(UnifiedAggregate.self, forKey: .arguments)
        case "assertCollectionExists":
            self.operation = try container.decode(UnifiedAssertCollectionExists.self, forKey: .arguments)
        case "assertCollectionNotExists":
            self.operation = try container.decode(UnifiedAssertCollectionNotExists.self, forKey: .arguments)
        case "assertIndexExists":
            self.operation = try container.decode(UnifiedAssertIndexExists.self, forKey: .arguments)
        case "assertIndexNotExists":
            self.operation = try container.decode(UnifiedAssertIndexNotExists.self, forKey: .arguments)
        case "assertDifferentLsidOnLastTwoCommands":
            self.operation = try container.decode(AssertDifferentLsidOnLastTwoCommands.self, forKey: .arguments)
        case "assertSameLsidOnLastTwoCommands":
            self.operation = try container.decode(AssertSameLsidOnLastTwoCommands.self, forKey: .arguments)
        case "assertSessionDirty":
            self.operation = try container.decode(AssertSessionDirty.self, forKey: .arguments)
        case "assertSessionNotDirty":
            self.operation = try container.decode(AssertSessionNotDirty.self, forKey: .arguments)
        case "assertSessionPinned":
            self.operation = try container.decode(UnifiedAssertSessionPinned.self, forKey: .arguments)
        case "assertSessionUnpinned":
            self.operation = try container.decode(UnifiedAssertSessionUnpinned.self, forKey: .arguments)
        case "assertSessionTransactionState":
            self.operation = try container.decode(UnifiedAssertSessionTransactionState.self, forKey: .arguments)
        case "bulkWrite":
            self.operation = try container.decode(UnifiedBulkWrite.self, forKey: .arguments)
        case "commitTransaction":
            self.operation = UnifiedCommitTransaction()
        case "countDocuments":
            self.operation = try container.decode(UnifiedCountDocuments.self, forKey: .arguments)
        case "createChangeStream":
            self.operation = try container.decode(CreateChangeStream.self, forKey: .arguments)
        case "createCollection":
            self.operation = try container.decode(UnifiedCreateCollection.self, forKey: .arguments)
        case "createIndex":
            self.operation = try container.decode(UnifiedCreateIndex.self, forKey: .arguments)
        case "deleteOne":
            self.operation = try container.decode(UnifiedDeleteOne.self, forKey: .arguments)
        case "deleteMany":
            self.operation = try container.decode(UnifiedDeleteMany.self, forKey: .arguments)
        case "distinct":
            self.operation = try container.decode(UnifiedDistinct.self, forKey: .arguments)
        case "dropCollection":
            self.operation = try container.decode(UnifiedDropCollection.self, forKey: .arguments)
        case "endSession":
            self.operation = EndSession()
        case "estimatedDocumentCount":
            if container.allKeys.contains(.arguments) {
                self.operation = try container.decode(UnifiedEstimatedDocumentCount.self, forKey: .arguments)
            } else {
                self.operation = UnifiedEstimatedDocumentCount()
            }
        case "find":
            self.operation = try container.decode(UnifiedFind.self, forKey: .arguments)
        case "findOneAndReplace":
            self.operation = try container.decode(UnifiedFindOneAndReplace.self, forKey: .arguments)
        case "findOneAndUpdate":
            self.operation = try container.decode(UnifiedFindOneAndUpdate.self, forKey: .arguments)
        case "findOneAndDelete":
            self.operation = try container.decode(UnifiedFindOneAndDelete.self, forKey: .arguments)
        case "failPoint":
            self.operation = try container.decode(UnifiedFailPoint.self, forKey: .arguments)
        case "insertOne":
            self.operation = try container.decode(UnifiedInsertOne.self, forKey: .arguments)
        case "insertMany":
            self.operation = try container.decode(UnifiedInsertMany.self, forKey: .arguments)
        case "iterateUntilDocumentOrError":
            self.operation = IterateUntilDocumentOrError()
        case "listDatabases":
            self.operation = UnifiedListDatabases()
        case "replaceOne":
            self.operation = try container.decode(UnifiedReplaceOne.self, forKey: .arguments)
        case "runCommand":
            self.operation = try container.decode(UnifiedRunCommand.self, forKey: .arguments)
        case "startTransaction":
            self.operation = UnifiedStartTransaction()
        case "targetedFailPoint":
            self.operation = try container.decode(UnifiedTargetedFailPoint.self, forKey: .arguments)
        case "updateOne":
            self.operation = try container.decode(UnifiedUpdateOne.self, forKey: .arguments)
        case "updateMany":
            self.operation = try container.decode(UnifiedUpdateMany.self, forKey: .arguments)
        // GridFS ops
        case "delete", "download", "upload":
            self.operation = Placeholder()
        // convenient txn API
        case "withTransaction":
            self.operation = Placeholder()
        default:
            throw TestError(message: "unrecognized operation name \(self.name)")
        }

        if type(of: self.operation) != Placeholder.self,
           let rawArgs = try container.decodeIfPresent(BSONDocument.self, forKey: .arguments)?.keys
        {
            let knownArgsForType = type(of: self.operation).knownArguments
            for arg in rawArgs {
                guard knownArgsForType.contains(arg) else {
                    throw TestError(
                        message: "Unrecognized argument \"\(arg)\" for operation type \"\(type(of: self.operation))\""
                    )
                }
            }
        }

        self.object = try container.decode(Object.self, forKey: .object)

        let singleContainer = try decoder.singleValueContainer()
        let result = try singleContainer.decode(ExpectedOperationResult.self)
        guard !result.isEmpty else {
            self.expectedResult = nil
            return
        }

        self.expectedResult = result
    }
}

/// Placeholder for an unsupported operation.
struct Placeholder: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }

    func execute(on _: UnifiedOperation.Object, context _: Context) throws -> UnifiedOperationResult {
        fatalError("Unexpectedly tried to execute placeholder operation")
    }
}

/// Represents the expected result of an operation.
enum ExpectedOperationResult: Decodable {
    /// One or more assertions for an error expected to be raised by the operation.
    case error(ExpectedError)
    /// - result: A value corresponding to the expected result of the operation.
    /// - saveAsEntity: If specified, the actual result returned by the operation (if any) will be saved with this
    ///       name in the Entity Map.
    case result(result: BSON?, saveAsEntity: String?)

    private enum CodingKeys: String, CodingKey {
        case expectError, expectResult, saveResultAsEntity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let expectError = try container.decodeIfPresent(ExpectedError.self, forKey: .expectError) {
            self = .error(expectError)
            return
        }

        let expectResult = try container.decodeIfPresent(BSON.self, forKey: .expectResult)
        let saveAsEntity = try container.decodeIfPresent(String.self, forKey: .saveResultAsEntity)
        self = .result(result: expectResult, saveAsEntity: saveAsEntity)
    }

    /// If none of the fields are present we currently end up with an empty object. This allows us to check easily that
    /// there are not actually any result assertions to be made.
    var isEmpty: Bool {
        guard case let .result(result, save) = self else {
            return false
        }
        return result == nil && save == nil
    }
}

/// One or more assertions for an error/exception, which is expected to be raised by an executed operation.
struct ExpectedError: Decodable {
    /// If true, the test runner MUST assert that an error was raised. This is primarily used when no other error
    /// assertions apply but the test still needs to assert an expected error.
    let isError: Bool?

    /// When true, indicates that the error originated from the client. When false, indicates that the error
    /// originated from a server response.
    let isClientError: Bool?

    /// A substring of the expected error message (e.g. "errmsg" field in a server error document).
    let errorContains: String?

    /// The expected "code" field in the server-generated error response.
    let errorCode: Int?

    /// The expected "codeName" field in the server-generated error response.
    let errorCodeName: String?

    /// A list of error label strings that the error is expected to have.
    let errorLabelsContain: [String]?

    /// A list of error label strings that the error is expected not to have.
    let errorLabelsOmit: [String]?

    /// This field is only used in cases where the error includes a result (e.g. bulkWrite).
    let expectResult: BSON?
}
