import Foundation
import MongoSwiftSync
import TestsCommon

/// Generic error thrown when matching fails, containing the expected and actual values as well as the path taken to
/// get to them for nested assertions.
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

extension UnifiedOperationResult {
    /// Determines whether this result matches `expected`.
    func matches(expected: BSON, entities: EntityMap, context: Context) throws {
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
        }

        try actual.matches(expected, entities: entities, context: context)
    }
}

/// Enum representing types that can be matched against expected values.
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
    fileprivate func matches(_ expected: BSON, entities: EntityMap, context: Context) throws {
        switch expected {
        case let .document(expectedDoc):
            if expectedDoc.isSpecialOperator {
                try self.matchesSpecial(expectedDoc, entities: entities, context: context)
                return
            }

            switch self {
            case let .rootDocument(actualDoc), let .subDocument(actualDoc):
                for (k, v) in expectedDoc {
                    let actualValue = MatchableResult(from: actualDoc[k])
                    try context.withPushedElt(k) {
                        try actualValue.matches(v, entities: entities, context: context)
                    }
                }
            default:
                throw NonMatchingError(expected: expected, actual: self, context: context)
            }

            if case let .subDocument(actualDoc) = self {
                for k in actualDoc.keys {
                    try context.withPushedElt(k) {
                        guard expectedDoc.keys.contains(k) else {
                            throw NonMatchingError(expected: nil, actual: actualDoc[k], context: context)
                        }
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
                    try actualElts[i].matches(expectedArray[i], entities: entities, context: context)
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
    private func matchesSpecial(_ specialOperator: BSONDocument, entities: EntityMap, context: Context) throws {
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
            let entity = try entities.getEntity(id: id).asBSON()
            try self.matches(entity, entities: entities, context: context)
        case let .unsetOrMatches(value):
            if case .none = self {
                return
            }
            try self.matches(value, entities: entities, context: context)
        case let .sessionLsid(id):
            guard case let .subDocument(actualDoc) = self else {
                throw NonMatchingError(
                    expected: "type subdocument",
                    actual: "\(self) (type: \(type(of: self)))",
                    context: context
                )
            }
            let session = try entities.getEntity(id: id).asSession()
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
func matchesEvents(expected: [ExpectedEvent], actual: [CommandEvent], entities: EntityMap, context: Context) throws {
    guard actual.count == expected.count else {
        throw NonMatchingError(expected: expected, actual: actual, context: context)
    }

    for i in 0..<actual.count {
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
                        try actual.matches(.document(expectedCommand), entities: entities, context: context)
                    }
                }

                if let expectedDb = expectedStarted.databaseName {
                    try context.withPushedElt("databaseName") {
                        try equals(expected: expectedDb, actual: actualStarted.databaseName, context: context)
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
                        try actual.matches(.document(expectedReply), entities: entities, context: context)
                    }
                }
            case let (.commandFailed(expectedFailed), .failed(actualFailed)):
                if let expectedName = expectedFailed.commandName {
                    try context.withPushedElt("commandName") {
                        try equals(expected: expectedName, actual: actualFailed.commandName, context: context)
                    }
                }
            default:
                throw NonMatchingError(expected: expectedEvent, actual: actualEvent, context: context)
            }
        }
    }
}

func equals<T: Equatable>(expected: T, actual: T, context: Context) throws {
    guard actual == expected else {
        throw NonMatchingError(expected: expected, actual: actual, context: context)
    }
}
