import Foundation
@testable import MongoSwift
import TestsCommon

/// Generic error thrown when matching fails, containing the expected and actual values as well as the path taken to
/// get to them for nested assertions.
@available(macOS 10.15, *)
struct NonMatchingError: LocalizedError {
    let expected: String
    let actual: String
    let path: [String]

    public var errorDescription: String? {
        "Element at path \(self.path) did not match: expected \(self.expected), actual: \(self.actual)"
    }

    init(expected: Any?, actual: Any?, context: Context) {
        self.expected = expected == nil ? "nil" : String(reflecting: expected!)
        self.actual = actual == nil ? "nil" : String(reflecting: actual!)
        self.path = context.path
    }
}

@available(macOS 10.15, *)
extension UnifiedOperationResult {
    /// Determines whether this result matches `expected`.
    func matches(expected: BSON, context: Context) throws {
        let actual: MatchableResult
        switch self {
        case let .bson(bson):
            actual = MatchableResult(from: bson)
        case let .rootDocument(doc):
            actual = .rootDocument(doc)
        case let .rootDocumentArray(arr):
            actual = .rootDocumentArray(arr)
        case .none:
            actual = .none
        case let .changeStream(cs):
            throw NonMatchingError(expected: expected, actual: cs, context: context)
        case let .findCursor(c):
            throw NonMatchingError(expected: expected, actual: c, context: context)
        }

        try actual.matches(expected, context: context)
    }
}

/// Enum representing types that can be matched against expected values.
@available(macOS 10.15, *)
enum MatchableResult {
    /// A root document. i.e. a documents where extra keys are ignored when matching against an expected document.
    case rootDocument(BSONDocument)
    /// An array of root documents.
    case rootDocumentArray([BSONDocument])
    /// A (non-root) document.
    case subDocument(BSONDocument)
    /// An array of BSONs.
    case array([BSON])
    /// A non-document, non-array BSON.
    case scalar(BSON)
    /// A nil result.
    case none

    /// Initializes an instance of `MatchableResult` from a `BSON`.
    init(from bson: BSON?) {
        guard let bson = bson else {
            self = .none
            return
        }
        switch bson {
        case let .document(doc):
            self = .subDocument(doc)
        case let .array(arr):
            self = .array(arr)
        default:
            self = .scalar(bson)
        }
    }

    /// Determines whether `self` matches `expected`, recursing if needed for nested documents and arrays.
    fileprivate func matches(_ expected: BSON, context: Context) throws {
        switch expected {
        case let .document(expectedDoc):
            if expectedDoc.isSpecialOperator {
                try self.matchesSpecial(expectedDoc, context: context)
                return
            }

            switch self {
            case let .rootDocument(actualDoc), let .subDocument(actualDoc):
                for (k, v) in expectedDoc {
                    let actualValue = MatchableResult(from: actualDoc[k])
                    try context.withPushedElt(k) {
                        try actualValue.matches(v, context: context)
                    }
                }
            default:
                throw NonMatchingError(expected: expected, actual: self, context: context)
            }

            if case let .subDocument(actualDoc) = self {
                for k in actualDoc.keys {
                    guard expectedDoc.keys.contains(k) else {
                        throw NonMatchingError(
                            expected: "doc to not have key \(k)",
                            actual: actualDoc,
                            context: context
                        )
                    }
                }
            }

        case let .array(expectedArray):
            let actualElts: [MatchableResult]

            switch self {
            case let .rootDocumentArray(rootArray):
                actualElts = rootArray.map { .rootDocument($0) }
            case let .array(array):
                actualElts = array.map { MatchableResult(from: $0) }
            default:
                throw NonMatchingError(expected: expectedArray, actual: self, context: context)
            }

            guard actualElts.count == expectedArray.count else {
                throw NonMatchingError(expected: expectedArray, actual: actualElts, context: context)
            }

            for i in 0..<actualElts.count {
                try context.withPushedElt(String(i)) {
                    try actualElts[i].matches(expectedArray[i], context: context)
                }
            }

        case .int32, .int64, .double:
            try self.matchesNumber(expected, context: context)
        default:
            // if we made it here, the expected value is a non-document, non-array BSON, so we should expect `self` to
            // be a scalar value too.
            guard case let .scalar(bson) = self, bson == expected else {
                throw NonMatchingError(expected: expected, actual: self, context: context)
            }
        }
    }

    /// Determines whether `self` matches the provided BSON number.
    /// When comparing numeric types (excluding Decimal128), test runners MUST consider 32-bit, 64-bit, and floating
    /// point numbers to be equal if their values are numerically equivalent.
    private func matchesNumber(_ expected: BSON, context: Context) throws {
        guard case let .scalar(bson) = self,
              let actualDouble = bson.toDouble(),
              // fuzzy equals in case of e.g. rounding errors
              abs(actualDouble - expected.toDouble()!) < 0.0001
        else {
            throw NonMatchingError(expected: expected, actual: self, context: context)
        }
    }

    /// Determines whether `self` satisfies the provided special operator.
    private func matchesSpecial(_ specialOperator: BSONDocument, context: Context) throws {
        let op = SpecialOperator(from: specialOperator)
        switch op {
        case let .exists(shouldExist):
            switch self {
            case .none:
                guard !shouldExist else {
                    throw NonMatchingError(expected: "element to exist", actual: self, context: context)
                }
            default:
                guard shouldExist else {
                    throw NonMatchingError(expected: "element to not exist", actual: self, context: context)
                }
            }
        case let .type(expectedTypes):
            try self.matchesType(expectedTypes, context: context)
        case let .matchesEntity(id):
            let entity = try context.entities.getEntity(id: id).asBSON()
            try self.matches(entity, context: context)
        case let .unsetOrMatches(value):
            if case .none = self {
                return
            }
            try self.matches(value, context: context)
        case let .sessionLsid(id):
            guard case let .subDocument(actualDoc) = self else {
                throw NonMatchingError(
                    expected: "type subdocument",
                    actual: "\(self) (type: \(type(of: self)))",
                    context: context
                )
            }
            let session = try context.entities.getEntity(id: id).asSession()
            try equals(expected: session.id, actual: actualDoc, context: context)
        }
    }

    /// Determines whether `self` satisfies the $$type operator value `expectedType`.
    private func matchesType(_ expectedTypes: [String], context: Context) throws {
        let error = NonMatchingError(
            expected: "element to have one of the following types: \(expectedTypes)",
            actual: self,
            context: context
        )

        let actualType: BSONType
        switch self {
        case .none:
            throw error
        case .subDocument, .rootDocument:
            actualType = .document
        case .array, .rootDocumentArray:
            actualType = .array
        case let .scalar(bson):
            actualType = bson.type
        }

        guard expectedTypes.contains(where: { actualType.matchesTypeString($0) }) else {
            throw error
        }
    }
}

extension BSONType {
    fileprivate func matchesTypeString(_ typeString: String) -> Bool {
        // aliases from https://docs.mongodb.com/manual/reference/operator/query/type/#available-types
        switch typeString {
        case "double":
            return self == .double
        case "string":
            return self == .string
        case "object":
            return self == .document
        case "array":
            return self == .array
        case "binData":
            return self == .binary
        case "undefined":
            return self == .undefined
        case "objectId":
            return self == .objectID
        case "bool":
            return self == .bool
        case "date":
            return self == .datetime
        case "null":
            return self == .null
        case "regex":
            return self == .regex
        case "dbPointer":
            return self == .dbPointer
        case "javascript":
            return self == .code
        case "symbol":
            return self == .symbol
        case "javascriptWithScope":
            return self == .codeWithScope
        case "int":
            return self == .int32
        case "timestamp":
            return self == .timestamp
        case "long":
            return self == .int64
        case "decimal":
            return self == .decimal128
        case "minKey":
            return self == .minKey
        case "maxKey":
            return self == .maxKey
        default:
            fatalError("Unrecognized $$typeMatches value \(typeString)")
        }
    }
}

extension BSONDocument {
    /// Returns whether this document is a special matching operator.
    var isSpecialOperator: Bool {
        self.count == 1 && self.keys[0].starts(with: "$$")
    }
}

/// Enum representing possible special operators.
enum SpecialOperator {
    case exists(Bool)
    /// $$type can be either a single string or array of strings. For simplicity we always store it as an array.
    case type([String])
    case matchesEntity(id: String)
    case unsetOrMatches(BSON)
    case sessionLsid(id: String)

    init(from document: BSONDocument) {
        let (op, value) = document.first!
        switch op {
        case "$$exists":
            self = .exists(value.boolValue!)
        case "$$type":
            if let str = value.stringValue {
                self = .type([str])
            } else {
                self = .type(value.arrayValue!.map { $0.stringValue! })
            }
        case "$$matchesEntity":
            self = .matchesEntity(id: value.stringValue!)
        case "$$unsetOrMatches":
            self = .unsetOrMatches(value)
        case "$$sessionLsid":
            self = .sessionLsid(id: value.stringValue!)
        default:
            fatalError("Unrecognized special operator \(op)")
        }
    }
}

/// Determines if the events in `actual` match the events in `expected`.
func matchesEvents(
    expected: [ExpectedEvent],
    actual: [CommandEvent],
    context: Context,
    ignoreExtraEvents: Bool
) throws {
    // Ensure correct amount of events present (or more than enough if ignorable)
    guard (actual.count == expected.count) || (ignoreExtraEvents && actual.count >= expected.count) else {
        throw NonMatchingError(expected: expected, actual: actual, context: context)
    }

    for i in 0..<expected.count {
        try context.withPushedElt(String(i)) {
            let expectedEvent = expected[i]
            let actualEvent = actual[i]

            switch (expectedEvent, actualEvent) {
            case let (.commandStarted(expectedStarted), .started(actualStarted)):
                if let expectedName = expectedStarted.commandName {
                    try context.withPushedElt("commandName") {
                        try equals(expected: expectedName, actual: actualStarted.commandName, context: context)
                    }
                }

                if let expectedCommand = expectedStarted.command {
                    let actual = MatchableResult.rootDocument(actualStarted.command)
                    try context.withPushedElt("command") {
                        try actual.matches(.document(expectedCommand), context: context)
                    }
                }

                if let expectedDb = expectedStarted.databaseName {
                    try context.withPushedElt("databaseName") {
                        try equals(expected: expectedDb, actual: actualStarted.databaseName, context: context)
                    }
                }

                if let hasServiceId = expectedStarted.hasServiceId {
                    try context.withPushedElt("hasServiceId") {
                        try equals(expected: hasServiceId, actual: actualStarted.serviceID != nil, context: context)
                    }
                }

            case let (.commandSucceeded(expectedSucceeded), .succeeded(actualSucceeded)):
                if let expectedName = expectedSucceeded.commandName {
                    try context.withPushedElt("commandName") {
                        try equals(expected: expectedName, actual: actualSucceeded.commandName, context: context)
                    }
                }

                if let expectedReply = expectedSucceeded.reply {
                    let actual = MatchableResult.rootDocument(actualSucceeded.reply)
                    try context.withPushedElt("reply") {
                        try actual.matches(.document(expectedReply), context: context)
                    }
                }

                if let hasServiceId = expectedSucceeded.hasServiceId {
                    try context.withPushedElt("hasServiceId") {
                        try equals(expected: hasServiceId, actual: actualSucceeded.serviceID != nil, context: context)
                    }
                }

            case let (.commandFailed(expectedFailed), .failed(actualFailed)):
                if let expectedName = expectedFailed.commandName {
                    try context.withPushedElt("commandName") {
                        try equals(expected: expectedName, actual: actualFailed.commandName, context: context)
                    }
                }

                if let hasServiceId = expectedFailed.hasServiceId {
                    try context.withPushedElt("hasServiceId") {
                        try equals(expected: hasServiceId, actual: actualFailed.serviceID != nil, context: context)
                    }
                }

            default:
                throw NonMatchingError(expected: expectedEvent, actual: actualEvent, context: context)
            }
        }
    }
}

/// Test protocol used to indicate an error has one or more error codes and codenames. We use an array since
/// BulkWriteErrors may have multiple failures and we need to be able to check if any of them match.
protocol HasErrorCodes: MongoErrorProtocol {
    var errorCodes: [MongoError.ServerErrorCode] { get }
    var errorCodeNames: [String] { get }
}

extension MongoError.CommandError: HasErrorCodes {
    var errorCodes: [MongoError.ServerErrorCode] { [self.code] }
    var errorCodeNames: [String] { [self.codeName] }
}

extension MongoError.WriteError: HasErrorCodes {
    var errorCodes: [MongoError.ServerErrorCode] {
        if let code = self.writeFailure?.code {
            return [code]
        } else if let code = self.writeConcernFailure?.code {
            return [code]
        }
        return []
    }

    var errorCodeNames: [String] {
        if let codeName = self.writeFailure?.codeName {
            return [codeName]
        } else if let codeName = self.writeConcernFailure?.codeName {
            return [codeName]
        }
        return []
    }
}

extension MongoError.BulkWriteError: HasErrorCodes {
    var errorCodes: [MongoError.ServerErrorCode] {
        var codes = self.writeFailures?.map { $0.code } ?? []
        if let wcCode = self.writeConcernFailure?.code {
            codes.append(wcCode)
        }
        return codes
    }

    var errorCodeNames: [String] {
        var codeNames = self.writeFailures?.map { $0.codeName } ?? []
        if let wcCodeName = self.writeConcernFailure?.codeName {
            codeNames.append(wcCodeName)
        }
        return codeNames
    }
}

@available(macOS 10.15, *)
extension MongoErrorProtocol {
    func matches(_ expected: ExpectedError, context: Context) throws {
        if let isClientError = expected.isClientError {
            try context.withPushedElt("isClientError") {
                guard isClientError == self.isClientError else {
                    throw NonMatchingError(
                        expected: "Error \(isClientError ? "" : "not") to be a client error",
                        actual: self,
                        context: context
                    )
                }
            }
        }

        if let errorContains = expected.errorContains {
            try context.withPushedElt("errorContains") {
                guard self.errorDescription!.lowercased().contains(errorContains.lowercased()) else {
                    throw NonMatchingError(
                        expected: "error message to contain \(errorContains)",
                        actual: self,
                        context: context
                    )
                }
            }
        }

        if let errorCode = expected.errorCode {
            try context.withPushedElt("errorCode") {
                guard let actualWithCodes = self as? HasErrorCodes else {
                    throw NonMatchingError(
                        expected: "error to have error code(s)",
                        actual: self,
                        context: context
                    )
                }

                guard actualWithCodes.errorCodes.contains(errorCode) else {
                    throw NonMatchingError(
                        expected: "error to have error code \(errorCode)",
                        actual: actualWithCodes,
                        context: context
                    )
                }
            }
        }

        if let codeName = expected.errorCodeName {
            try context.withPushedElt("errorCodeName") {
                guard let actualWithCodeNames = self as? HasErrorCodes else {
                    throw NonMatchingError(
                        expected: "error to have error code(s)",
                        actual: self,
                        context: context
                    )
                }
                // TODO: SWIFT-1022: Due to CDRIVER-3147 many of our errors are currently missing code names, so we
                // have to accept an empty string (i.e. unset) here as well as an actual code name.
                let actualCodes = actualWithCodeNames.errorCodeNames
                guard actualCodes.contains(codeName) || actualCodes.contains("") else {
                    throw NonMatchingError(
                        expected: "error to have codeName \"\(codeName)\" or \"\"",
                        actual: self,
                        context: context
                    )
                }
            }
        }

        if let errorLabelsContain = expected.errorLabelsContain {
            try context.withPushedElt("errorLabelsContain") {
                guard let actualLabeled = self as? MongoLabeledError else {
                    throw NonMatchingError(
                        expected: "error to conform to MongoLabeledError",
                        actual: self,
                        context: context
                    )
                }

                guard let actualLabels = actualLabeled.errorLabels else {
                    throw NonMatchingError(
                        expected: "error to have error labels",
                        actual: actualLabeled,
                        context: context
                    )
                }

                for (i, expectedLabel) in errorLabelsContain.enumerated() {
                    try context.withPushedElt(String(i)) {
                        guard actualLabels.contains(expectedLabel) else {
                            throw NonMatchingError(
                                expected: "error to have error label \(expectedLabel)",
                                actual: actualLabeled,
                                context: context
                            )
                        }
                    }
                }
            }
        }

        if let errorLabelsOmit = expected.errorLabelsOmit {
            try context.withPushedElt("errorLabelsOmit") {
                guard let actualLabeled = self as? MongoLabeledError else {
                    throw NonMatchingError(
                        expected: "error to conform to MongoLabeledError",
                        actual: self,
                        context: context
                    )
                }

                let actualLabels = actualLabeled.errorLabels ?? []

                for (i, shouldOmitLabel) in errorLabelsOmit.enumerated() {
                    try context.withPushedElt(String(i)) {
                        guard !actualLabels.contains(shouldOmitLabel) else {
                            throw NonMatchingError(
                                expected: "error to not have error label \(shouldOmitLabel)",
                                actual: actualLabeled,
                                context: context
                            )
                        }
                    }
                }
            }
        }

        if let expectResult = expected.expectResult {
            try context.withPushedElt("expectResult") {
                // currently the only type of error with a nested result.
                guard let bulkError = self as? MongoError.BulkWriteError else {
                    throw NonMatchingError(
                        expected: "error to be a BulkWriteError",
                        actual: self,
                        context: context
                    )
                }

                guard let result = bulkError.result else {
                    throw NonMatchingError(
                        expected: "BulkWriteError to have a result",
                        actual: bulkError,
                        context: context
                    )
                }

                let encodedResult = try BSONEncoder().encode(result)
                try MatchableResult.rootDocument(encodedResult).matches(expectResult, context: context)
            }
        }
    }
}

@available(macOS 10.15, *)
func equals<T: Equatable>(expected: T, actual: T, context: Context) throws {
    guard actual == expected else {
        throw NonMatchingError(expected: expected, actual: actual, context: context)
    }
}
