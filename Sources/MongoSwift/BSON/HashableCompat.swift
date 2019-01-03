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
    /// Equatable conformance
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
        // and https://github.com/krzysztofzablocki/Sourcery
        #if arch(x86_64) || arch(arm64)
        let magic: UInt = 0x9e3779b97f4a7c15
        #elseif arch(i386) || arch(arm)
        let magic: UInt = 0x9e3779b9
        #endif
        var lhs = UInt(bitPattern: hashValue)
        let rhs = UInt(bitPattern: hashable.hashValue)
        lhs ^= rhs &+ magic &+ (lhs << 6) &+ (lhs >> 2)
        self.hashValue = Int(bitPattern: lhs)
    }

    func finalize() -> Int {
        return hashValue ?? 0
    }
}
#endif
