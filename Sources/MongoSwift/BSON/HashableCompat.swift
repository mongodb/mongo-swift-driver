import Foundation

internal protocol HashableCompat: Hashable {
    func hashCompat(into hasher: inout Hasher)
}

extension HashableCompat {
    #if swift(>=4.2)
    public func hash(into hasher: inout Hasher) {
        self.hashCompat(into: &hasher)
    }
    #else
    public var hashValue: Int {
        var hasher = Hasher()
        self._hash(into: &hasher)
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
extension BSONValue {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return bsonEquals(lhs, rhs)
    }
}

internal struct Hasher {
    private var hashValue: Int?

    mutating func combine<T: Hashable>(_ hashable: T) {
        guard let hashValue = self.hashValue else {
            self.hashValue = hashable.hashValue
            return
        }
        self.hashValue! ^= hashable.hashValue + 0x9e3779b9 + (hashValue << 6) + (hashValue >> 2)
    }

    func finalize() -> Int {
        return hashValue ?? 0
    }
}
#endif
