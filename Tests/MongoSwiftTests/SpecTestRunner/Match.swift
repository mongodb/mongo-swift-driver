import Foundation
import MongoSwift
import Nimble

// swiftlint:disable line_length
/// Protocol that allows a type to assert it matches a given value according to the specs' MATCHES function.
/// https://github.com/mongodb/specifications/tree/master/source/connection-monitoring-and-pooling/tests#spec-test-match-function
internal protocol Matchable {
    /// Returns whether this MATCHES the expected value according to the function defined in the spec.
    /// This assumes `expected` is NOT a placeholder value (i.e. 42/"42"). Use `matches` if `expected` may be a
    /// placeholder.
    /// https://github.com/mongodb/specifications/tree/master/source/connection-monitoring-and-pooling/tests#spec-test-match-function
    func contentMatches(expected: Any) -> Bool
}
// swiftlint:enable line_length

extension Matchable {
    /// Returns whether this MATCHES the expected value according to the function defined in the spec.
    internal func matches(expected: Any) -> Bool {
        return isPlaceholder(expected) || self.contentMatches(expected: expected)
    }
}

/// Extension that adds MATCHES functionality to `Array`.
extension Array: Matchable {
    internal func contentMatches(expected: Any) -> Bool {
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
    internal func contentMatches(expected: Any) -> Bool {
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

// swiftlint:disable line_length
/// A Nimble matcher for the MATCHES function defined in the spec.
/// https://github.com/mongodb/specifications/tree/master/source/connection-monitoring-and-pooling/tests#spec-test-match-function
internal func match(_ expectedValue: Any?) -> Predicate<Matchable> {
    // swiftlint:enable line_length
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
