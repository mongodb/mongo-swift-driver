import Foundation

/*
 Internal mechanism for Hashable conformance
 over varying swift versions
*/
internal protocol HashableCompat: Hashable {
    /// Method to defer to when hashing
    func hashCompat(into hasher: inout Hasher)
}

extension HashableCompat {
    #if swift(>=4.2)
    /// Hash method which defers to hashCompat
    public func hash(into hasher: inout Hasher) {
        self.hashCompat(into: &hasher)
    }
    #else
    // swiftlint:disable:next legacy_hashing
    /// Legacy hash value which defers to hashcompat
    public var hashValue: Int {
        var hasher = Hasher()
        self.hashCompat(into: &hasher)
        return hasher.finalize()
    }
    #endif
}

extension Int: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension Int32: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension Int64: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension Date: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension Double: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension Bool: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension String: HashableCompat {
    func hashCompat(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

#if !swift(>=4.2)
/// Synthesized equatable conformance for BSONValue
extension BSONValue {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return bsonEquals(lhs, rhs)
    }
}

/// Compat structure for Hasher if not swift >= 4.2
internal struct Hasher {
    /// Current hashValue
    private var hashValue: Int?

    /*
     Combine next hashable hashValue
      - parameter hashable: hashable to combine
     */
    mutating func combine<T: Hashable>(_ hashable: T) {
        // if this is our first value, take the hashValue
        guard let hashValue = self.hashValue else {
            self.hashValue = hashable.hashValue
            return
        }
        // else, combine the hashValues. adapted from
        // https://www.boost.org/doc/libs/1_64_0/boost/functional/hash/hash.hpp
        self.hashValue! ^= hashable.hashValue + 0x9e3779b9 + (hashValue << 6) + (hashValue >> 2)
    }

    func finalize() -> Int {
        return hashValue ?? 0
    }
}
#endif
