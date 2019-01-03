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
        // else, see: https://github.com/apple/swift-evolution/blob/master/proposals/0206-hashable-enhancements.md#source-compatibility
        self.hashValue! = hashValue ^ hashable.hashValue &* 16777619
    }

    func finalize() -> Int {
        return hashValue ?? 0
    }
}
#endif
