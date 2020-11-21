import MongoSwiftSync
import TestsCommon

extension UnifiedOperationResult {
    /// Determines whether this result matches `expected`. `opReturnsRootDocs` should be set to `true` if this result
    /// was obtained from an operation that returns root documents.
    func matches(expected: BSON, entities: EntityMap, opReturnsRootDocs: Bool) throws -> Bool {
        let actual: BSON?
        switch self {
        case let .bson(bson):
            actual = bson
        case .none:
            actual = nil
        default:
            return false
        }

        return try matchesInner(
            expected: expected,
            actual: actual,
            entities: entities,
            isRoot: true,
            containsRootDocs: opReturnsRootDocs
        )
    }
}

/// Determines whether `actual` matches `expected`, recursing if needed for nested documents and arrays. `isRoot`
/// should be set to `true` if `expected` is a root document per the spec. `containsRootDocs` should be set to true if
/// `expected` is a top-level array which contains root documents.
func matchesInner(
    expected: BSON,
    actual: BSON?,
    entities: EntityMap,
    isRoot: Bool = false,
    containsRootDocs: Bool = false
) throws -> Bool {
    switch expected {
    case let .document(expectedDoc):
        if expectedDoc.isSpecialOperator {
            return try matchesSpecial(operatorDoc: expectedDoc, actual: actual, entities: entities)
        }

        // The only case in which nil is an acceptable value is if the expected document is a special operator;
        // otherwise, the two documents do not match.
        guard let actualDoc = actual?.documentValue else {
            return false
        }

        for (k, v) in expectedDoc {
            guard try matchesInner(expected: v, actual: actualDoc[k], entities: entities) else {
                return false
            }
        }

        // Documents that are not the root-level document should not contain extra keys.
        if !isRoot {
            for k in actualDoc.keys {
                guard expectedDoc.keys.contains(k) else {
                    return false
                }
            }
        }

        return true
    case let .array(expectedArray):
        guard let actualArray = actual?.arrayValue else {
            return false
        }

        guard actualArray.count == expectedArray.count else {
            return false
        }

        for (actualElt, expectedElt) in zip(actualArray, expectedArray) {
            guard try matchesInner(
                expected: expectedElt,
                actual: actualElt,
                entities: entities,
                isRoot: containsRootDocs
            ) else {
                return false
            }
        }

        return true
    case .int32, .int64, .double:
        return matchNumbers(expected: expected, actual: actual)
    default:
        return actual == expected
    }
}

/// When comparing numeric types (excluding Decimal128), test runners MUST consider 32-bit, 64-bit, and floating point
/// numbers to be equal if their values are numerically equivalent.
func matchNumbers(expected: BSON, actual: BSON?) -> Bool {
    guard let actualDouble = actual?.toDouble() else {
        return false
    }
    return actualDouble == expected.toDouble()!
}

extension BSONDocument {
    /// Returns whether this document is a special matching operator.
    var isSpecialOperator: Bool {
        self.count == 1 && self.keys[0].starts(with: "$$")
    }
}

/// Determines whether `actual` satisfies the special matching operator in the provided `operatorDoc`.
func matchesSpecial(operatorDoc: BSONDocument, actual: BSON?, entities: EntityMap) throws -> Bool {
    let (op, value) = operatorDoc.first!
    switch op {
    case "$$exists":
        return value.boolValue! == (actual != nil)
    case "$$type":
        return try typeMatches(expectedType: value, actual: actual)
    case "$$matchesEntity":
        guard let id = value.stringValue else {
            throw TestError(
                message: "Expected $$matchesEntity to be a string, got \(value) with type \(type(of: value))"
            )
        }
        let entity = try entities.getEntity(id: id).asBSON()
        return try matchesInner(expected: entity, actual: actual, entities: entities)
    case "$$matchesHexBytes":
        throw TestError(message: "Unsupported special operator $$matchesHexBytes")
    case "$$unsetOrMatches":
        return try actual == nil || matchesInner(expected: value, actual: actual, entities: entities)
    case "$$sessionLsid":
        guard let id = value.stringValue else {
            throw TestError(
                message: "Expected $$sessionLsid to be a string, got \(value) with type \(type(of: value))"
            )
        }
        let session = try entities.getEntity(id: id).asSession()
        return actual?.documentValue == session.id
    default:
        throw TestError(message: "Unrecognized special operator \(op)")
    }
}

/// Determines whether `actual` satisfies the $$type operator value `expectedType`.
func typeMatches(expectedType: BSON, actual: BSON?) throws -> Bool {
    guard let actual = actual else {
        return false
    }
    guard let typeString = expectedType.stringValue else {
        throw TestError(
            message: "Expected $$type to be a string, got \(expectedType) with type \(type(of: expectedType))"
        )
    }
    // aliases from https://docs.mongodb.com/manual/reference/operator/query/type/#available-types
    switch typeString {
    case "double":
        return actual.type == .double
    case "string":
        return actual.type == .string
    case "object":
        return actual.type == .document
    case "array":
        return actual.type == .array
    case "binData":
        return actual.type == .binary
    case "undefined":
        return actual.type == .undefined
    case "objectId":
        return actual.type == .objectID
    case "bool":
        return actual.type == .bool
    case "date":
        return actual.type == .datetime
    case "null":
        return actual.type == .null
    case "regex":
        return actual.type == .regex
    case "dbPointer":
        return actual.type == .dbPointer
    case "javascript":
        return actual.type == .code
    case "symbol":
        return actual.type == .symbol
    case "javascriptWithScope":
        return actual.type == .codeWithScope
    case "int":
        return actual.type == .int32
    case "timestamp":
        return actual.type == .timestamp
    case "long":
        return actual.type == .int64
    case "decimal":
        return actual.type == .decimal128
    case "minKey":
        return actual.type == .minKey
    case "maxKey":
        return actual.type == .maxKey
    default:
        throw TestError(message: "Unrecognized $$typeMatches value \(typeString)")
    }
}

/// Determiens the events in `actual` match the events in `expected`.
func eventsMatch(expected: [ExpectedEvent], actual: [CommandEvent], entities: EntityMap) throws -> Bool {
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
                    actual: .document(actualStarted.command),
                    entities: entities,
                    isRoot: true
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
                    actual: .document(actualSucceeded.reply),
                    entities: entities,
                    isRoot: true
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
