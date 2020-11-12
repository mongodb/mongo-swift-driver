import Foundation
import MongoSwiftSync
import TestsCommon

/// Protocol which all operations supported by the unified test runner conform to.
protocol UnifiedOperationProtocol: Decodable {
    /// Set of supported arguments for the operation.
    static var knownArguments: Set<String> { get }
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
    }

    /// Object on which to perform the operation.
    let object: Object

    /// Specific operation to execute.
    let operation: UnifiedOperationProtocol

    /// Expected result of the operation.
    let result: UnifiedOperationResult?

    private enum CodingKeys: String, CodingKey {
        case name, object, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        switch name {
        case "assertDifferentLsidOnLastTwoCommands":
            self.operation = try container.decode(AssertDifferentLsidOnLastTwoCommands.self, forKey: .arguments)
        case "assertSameLsidOnLastTwoCommands":
            self.operation = try container.decode(AssertSameLsidOnLastTwoCommands.self, forKey: .arguments)
        case "assertSessionNotDirty":
            self.operation = try container.decode(AssertSessionNotDirty.self, forKey: .arguments)
        case "createChangeStream":
            self.operation = try container.decode(CreateChangeStream.self, forKey: .arguments)
        case "endSession":
            self.operation = EndSession()
        case "find":
            self.operation = try container.decode(Find.self, forKey: .arguments)
        case "failPoint":
            self.operation = try container.decode(UnifiedFailPoint.self, forKey: .arguments)
        case "insertOne":
            self.operation = try container.decode(InsertOne.self, forKey: .arguments)
        case "iterateUntilDocumentOrError":
            self.operation = IterateUntilDocumentOrError()
        default:
            // this is temporary so the tests compile/pass even though we don't have all the operations yet
            self.operation = Placeholder()
        }

        if type(of: self.operation) != Placeholder.self,
            let rawArgs = try container.decodeIfPresent(BSONDocument.self, forKey: .arguments)?.keys {
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
        let result = try singleContainer.decode(UnifiedOperationResult.self)
        guard !result.isEmpty else {
            self.result = nil
            return
        }

        self.result = result
    }
}

struct Placeholder: UnifiedOperationProtocol {
    static var knownArguments: Set<String> { [] }
}

/// Represents the expected result of an operation.
enum UnifiedOperationResult: Decodable {
    /// One or more assertions for an error expected to be raised by the operation.
    case error(ExpectedError)
    /// - result: A value corresponding to the expected result of the operation.
    /// - saveAsEntity: If specified, the actual result returned by the operation (if any) will be saved with this
    ///       name in the Entity Map.
    // TODO: SWIFT-913: consider using custom type to represent results
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
    // TODO: SWIFT-913: consider using custom type to represent results
    let expectResult: BSON?
}
