import MongoSwiftSync
import TestsCommon

extension UnifiedOperationResult {
    /// Determines whether this result matches `expected`.
    func matches(expected: BSON, entities: EntityMap) throws -> Bool {
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
        default:
            return false
        }

        return try actual.matches(expected, entities: entities)
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
    fileprivate func matches(_ expected: BSON, entities: EntityMap) throws -> Bool {
        switch expected {
        case let .document(expectedDoc):
            if expectedDoc.isSpecialOperator {
                return try self.matchesSpecial(expectedDoc, entities: entities)
            }

            switch self {
            case let .rootDocument(actualDoc), let .subDocument(actualDoc):
                for (k, v) in expectedDoc {
                    let actualValue = MatchableResult(from: actualDoc[k])
                    guard try actualValue.matches(v, entities: entities) else {
                        return false
                    }
                }
            default:
                return false
            }

            // Documents that are not the root-level document should not contain extra keys.
            if case let .subDocument(actualDoc) = self {
                for k in actualDoc.keys {
                    guard expectedDoc.keys.contains(k) else {
                        return false
                    }
                }
            }

            return true
        case let .array(expectedArray):
            let actualElts: [MatchableResult]

            switch self {
            case let .rootDocumentArray(rootArray):
                actualElts = rootArray.map { .rootDocument($0) }
            case let .array(array):
                actualElts = array.map { MatchableResult(from: $0) }
            default:
                return false
            }

            guard actualElts.count == expectedArray.count else {
                return false
            }

            for (actualElt, expectedElt) in zip(actualElts, expectedArray) {
                guard try actualElt.matches(expectedElt, entities: entities) else {
                    return false
                }
            }

            return true
        case .int32, .int64, .double:
            return self.matchesNumber(expected)
        default:
            // if we made it here, the expected value is a non-document, non-array BSON, so we should expect `self` to
            // be a scalar value too.
            guard case let .scalar(bson) = self else {
                return false
            }
            return bson == expected
        }
    }

    /// When comparing numeric types (excluding Decimal128), test runners MUST consider 32-bit, 64-bit, and floating
    /// point numbers to be equal if their values are numerically equivalent.
    private func matchesNumber(_ expected: BSON) -> Bool {
        guard case let .scalar(bson) = self else {
            return false
        }
        guard let actualDouble = bson.toDouble() else {
            return false
        }

        // fuzzy equals in case of e.g. rounding errors
        return abs(actualDouble - expected.toDouble()!) < 0.0001
    }

    /// Determines whether `self` satisfies the special matching operator in the provided `operatorDoc`.
    private func matchesSpecial(_ specialOperator: BSONDocument, entities: EntityMap) throws -> Bool {
        let op = SpecialOperator(from: specialOperator)
        switch op {
        case let .exists(shouldExist):
            switch self {
            case .none:
                return !shouldExist
            default:
                return shouldExist
            }
        case let .type(expectedTypes):
            return self.matchesType(expectedTypes)
        case let .matchesEntity(id):
            let entity = try entities.getEntity(id: id).asBSON()
            return try self.matches(entity, entities: entities)
        case let .unsetOrMatches(value):
            if case .none = self {
                return true
            }
            return try self.matches(value, entities: entities)
        case let .sessionLsid(id):
            guard case let .subDocument(actualDoc) = self else {
                return false
            }
            let session = try entities.getEntity(id: id).asSession()
            return actualDoc == session.id
        }
    }

    /// Determines whether `self` satisfies the $$type operator value `expectedType`.
    private func matchesType(_ expectedTypes: [String]) -> Bool {
        let actualType: BSONType
        switch self {
        case .none:
            return false
        case .subDocument, .rootDocument:
            actualType = .document
        case .array, .rootDocumentArray:
            actualType = .array
        case let .scalar(bson):
            actualType = bson.type
        }

        return expectedTypes.contains { actualType.matchesTypeString($0) }
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
func matchesEvents(expected: [ExpectedEvent], actual: [CommandEvent], entities: EntityMap) throws -> Bool {
    guard actual.count == expected.count else {
        return false
    }

    for (expectedEvent, actualEvent) in zip(expected, actual) {
        switch (expectedEvent, actualEvent) {
        case let (.commandStarted(expectedStarted), .started(actualStarted)):
            if let expectedName = expectedStarted.commandName {
                guard actualStarted.commandName == expectedName else {
                    return false
                }
            }

            if let expectedCommand = expectedStarted.command {
                let actual = MatchableResult.rootDocument(actualStarted.command)
                guard try actual.matches(.document(expectedCommand), entities: entities) else {
                    return false
                }
            }

            if let expectedDb = expectedStarted.databaseName {
                guard actualStarted.databaseName == expectedDb else {
                    return false
                }
            }
        case let (.commandSucceeded(expectedSucceeded), .succeeded(actualSucceeded)):
            if let expectedName = expectedSucceeded.commandName {
                guard actualSucceeded.commandName == expectedName else {
                    return false
                }
            }

            if let expectedReply = expectedSucceeded.reply {
                let actual = MatchableResult.rootDocument(actualSucceeded.reply)
                guard try actual.matches(.document(expectedReply), entities: entities) else {
                    return false
                }
            }
        case let (.commandFailed(expectedFailed), .failed(actualFailed)):
            if let expectedName = expectedFailed.commandName {
                guard actualFailed.commandName == expectedName else {
                    return false
                }
            }
        default:
            // event types don't match
            return false
        }
    }

    return true
}
