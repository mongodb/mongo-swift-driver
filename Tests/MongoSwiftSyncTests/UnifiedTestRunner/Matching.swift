import MongoSwiftSync
import TestsCommon

/// Enum representing types that can be matched against expected values.
enum MatchableResult {
    /// A root document. i.e. a documents where extra keys are ignored when matching against an expected document.
    case rootDocument(BSONDocument)
    /// An array of root documents.
    case rootDocumentArray([BSONDocument])
    /// A (non-root) document.
    case document(BSONDocument)
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
            self = .document(doc)
        case let .array(arr):
            self = .array(arr)
        default:
            self = .scalar(bson)
        }
    }
}

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

        return try matchesInner(
            expected: expected,
            actual: actual,
            entities: entities
        )
    }
}

/// Determines whether `actual` matches `expected`, recursing if needed for nested documents and arrays.
private func matchesInner(
    expected: BSON,
    actual: MatchableResult,
    entities: EntityMap
) throws -> Bool {
    switch expected {
    case let .document(expectedDoc):
        if expectedDoc.isSpecialOperator {
            return try matchesSpecial(operatorDoc: expectedDoc, actual: actual, entities: entities)
        }

        switch actual {
        case let .rootDocument(actualDoc), let .document(actualDoc):
            for (k, v) in expectedDoc {
                let actualValue = MatchableResult(from: actualDoc[k])
                guard try matchesInner(expected: v, actual: actualValue, entities: entities) else {
                    return false
                }
            }
        default:
            return false
        }

        // Documents that are not the root-level document should not contain extra keys.
        if case let .document(actualDoc) = actual {
            for k in actualDoc.keys {
                guard expectedDoc.keys.contains(k) else {
                    return false
                }
            }
        }

        return true
    case let .array(expectedArray):
        let actualElts: [MatchableResult]

        switch actual {
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
            guard try matchesInner(expected: expectedElt, actual: actualElt, entities: entities) else {
                return false
            }
        }

        return true
    case .int32, .int64, .double:
        return matchesNumber(expected: expected, actual: actual)
    default:
        // if we made it here, the expected value is a non-document, non-array BSON, so we should expect `actual` to be
        // a scalar value too.
        guard case let .scalar(bson) = actual else {
            return false
        }
        return bson == expected
    }
}

/// When comparing numeric types (excluding Decimal128), test runners MUST consider 32-bit, 64-bit, and floating point
/// numbers to be equal if their values are numerically equivalent.
func matchesNumber(expected: BSON, actual: MatchableResult) -> Bool {
    guard case let .scalar(bson) = actual else {
        return false
    }
    guard let actualDouble = bson.toDouble() else {
        return false
    }

    // fuzzy equals in case of e.g. rounding errors
    return abs(actualDouble - expected.toDouble()!) < 0.0001
}

extension BSONDocument {
    /// Returns whether this document is a special matching operator.
    var isSpecialOperator: Bool {
        self.count == 1 && self.keys[0].starts(with: "$$")
    }
}

/// Determines whether `actual` satisfies the special matching operator in the provided `operatorDoc`.
func matchesSpecial(operatorDoc: BSONDocument, actual: MatchableResult, entities: EntityMap) throws -> Bool {
    let (op, value) = operatorDoc.first!
    switch op {
    case "$$exists":
        let shouldExist = value.boolValue!
        switch actual {
        case .none:
            return !shouldExist
        default:
            return shouldExist
        }
    case "$$type":
        return matchesType(expectedType: value, actual: actual)
    case "$$matchesEntity":
        let id = value.stringValue!
        let entity = try entities.getEntity(id: id).asBSON()
        return try matchesInner(expected: entity, actual: actual, entities: entities)
    case "$$matchesHexBytes":
        throw TestError(message: "Unsupported special operator $$matchesHexBytes")
    case "$$unsetOrMatches":
        if case .none = actual {
            return true
        }
        return try matchesInner(expected: value, actual: actual, entities: entities)
    case "$$sessionLsid":
        guard case let .document(actualDoc) = actual else {
            return false
        }
        let id = value.stringValue!
        let session = try entities.getEntity(id: id).asSession()
        return actualDoc == session.id
    default:
        fatalError("Unrecognized special operator \(op)")
    }
}

/// Determines whether `actual` satisfies the $$type operator value `expectedType`.
func matchesType(expectedType: BSON, actual: MatchableResult) -> Bool {
    let actualType: BSONType
    switch actual {
    case .none:
        return false
    case .document, .rootDocument:
        actualType = .document
    case .array, .rootDocumentArray:
        actualType = .array
    case let .scalar(bson):
        actualType = bson.type
    }

    let typeString = expectedType.stringValue!
    // aliases from https://docs.mongodb.com/manual/reference/operator/query/type/#available-types
    switch typeString {
    case "double":
        return actualType == .double
    case "string":
        return actualType == .string
    case "object":
        return actualType == .document
    case "array":
        return actualType == .array
    case "binData":
        return actualType == .binary
    case "undefined":
        return actualType == .undefined
    case "objectId":
        return actualType == .objectID
    case "bool":
        return actualType == .bool
    case "date":
        return actualType == .datetime
    case "null":
        return actualType == .null
    case "regex":
        return actualType == .regex
    case "dbPointer":
        return actualType == .dbPointer
    case "javascript":
        return actualType == .code
    case "symbol":
        return actualType == .symbol
    case "javascriptWithScope":
        return actualType == .codeWithScope
    case "int":
        return actualType == .int32
    case "timestamp":
        return actualType == .timestamp
    case "long":
        return actualType == .int64
    case "decimal":
        return actualType == .decimal128
    case "minKey":
        return actualType == .minKey
    case "maxKey":
        return actualType == .maxKey
    default:
        fatalError("Unrecognized $$typeMatches value \(typeString)")
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
                guard try matchesInner(
                    expected: .document(expectedCommand),
                    actual: .rootDocument(actualStarted.command),
                    entities: entities
                ) else {
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
                guard try matchesInner(
                    expected: .document(expectedReply),
                    actual: .rootDocument(actualSucceeded.reply),
                    entities: entities
                ) else {
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
