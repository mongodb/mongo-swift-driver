import Foundation
import MongoSwift
import Nimble

/// Protocol that allows a type to assert it matches a given value according to the specs' MATCHES function.
/// See: https://github.com/mongodb/specifications/tree/master/source/connection-monitoring-and-pooling/tests#spec-test-match-function
internal protocol Matchable {
    func matches(expected: Any) -> Bool
}

/// Extension that adds MATCHES functionality to `Array`.
extension Array: Matchable {
    internal func matches(expected: Any) -> Bool {
        guard !isPlaceholder(expected) else {
            return true
        }

        guard let expected = expected as? [Any], expected.count <= self.count else {
            return false
        }

        for (aV, eV) in zip(self, expected) {
            if let matchable = aV as? Matchable {
                guard matchable.matches(expected: eV) else {
                    return false
                }
            } else if let actualBSON = aV as? BSONValue, let expectedBSON = eV as? BSONValue {
                guard actualBSON.bsonMatches(expected: expectedBSON) else {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }
}

/// Extension that adds MATCHES functionality to `Document`.
extension Document: Matchable {
    internal func matches(expected: Any) -> Bool {
        guard !isPlaceholder(expected) else {
            return true
        }

        guard let expected = expected as? Document else {
            return false
        }

        for (eK, eV) in expected {
            guard let aV = self[eK], aV.bsonMatches(expected: eV) else {
                return false
            }
        }
        return true
    }
}

/// Extension that adds MATCHES functionality to `BSONValue`.
extension BSONValue {
    internal func bsonMatches(expected: BSONValue) -> Bool {
        if let matchable = self as? Matchable {
            return matchable.matches(expected: expected)
        }
        return isPlaceholder(expected) || self.bsonEquals(expected)
    }
}

/// A Nimble matcher for the MATCHES function defined in the spec.
/// See: https://github.com/mongodb/specifications/tree/master/source/connection-monitoring-and-pooling/tests#spec-test-match-function
internal func match(_ expectedValue: Any?) -> Predicate<Matchable> {
    return Predicate.define("match <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()
        switch (expectedValue, actualValue) {
        case (nil, _?):
            return PredicateResult(status: .fail, message: msg.appendedBeNilHint())
        case (nil, nil), (_, nil):
            return PredicateResult(status: .fail, message: msg)
        case let (expected?, actual?):
            let matches = actual.matches(expected: expected)
            return PredicateResult(bool: matches, message: msg)
        }
    }
}

/// Determines if an expected value is considered a wildcard for the purposes of the MATCHES function.
internal func isPlaceholder(_ expected: Any) -> Bool {
    return (expected as? BSONNumber)?.intValue == 42 || expected as? String == "42"
}
