import Foundation

// TODO: figure out if Int.random is random enough to satisfy OID spec or if we need to pass in some custom PRNG.
// also unclear if the second 5 bytes are "process unique".

//   4 byte timestamp    5 byte process unique   3 byte counter
// |<----------------->|<---------------------->|<------------>|
// [----|----|----|----|----|----|----|----|----|----|----|----]
// 0                   4                   8                   12

public struct PureBSONObjectId {
    private static let counter = ObjectIdCounter()
    internal let data: Data

    public init() {
        var data = Data(capacity: 12)
        // append most significant 4 bytes
        let secondsSinceEpoch = Date().timeIntervalSince1970
        let timestamp = UInt32(secondsSinceEpoch).bigEndian
        withUnsafeBytes(of: timestamp) { bytes in
            data.append(Data(bytes))
        }

        // generate a unique number that uses at most 5 bytes
        let processUnique = UInt64.random(in: 0...UInt64(pow(2, 40.0))).bigEndian
        // append the least significant 5 bytes
        withUnsafeBytes(of: processUnique) { bytes in
            data.append(Data(bytes[3...7]))
        }
        // get the next number from the counter and append the least significant 3 bytes
        withUnsafeBytes(of: PureBSONObjectId.counter.next().bigEndian) { bytes in
            data.append(Data(bytes[1...3]))
        }
        self.data = data
    }

    internal var hexDescription: String {
        return self.data.reduce("") { $0 + String(format: "%02x", $1) }
    }
}

extension PureBSONObjectId: CustomStringConvertible {
    public var description: String {
        return self.hexDescription
    }
}

extension PureBSONObjectId: PureBSONValue {
    internal init(from data: Data) throws {
        self.data = data
    }

    internal func toBSON() -> Data {
        return self.data
    }
}

/// Threadsafe counter that generates an increasing sequence of values for ObjectIds.
internal class ObjectIdCounter {
    private let queue = DispatchQueue(label: "ObjectId counter queue")
    /// Current count. This variable must only be read and written within `queue.sync` blocks.
    private var count = UInt32.random(in: 0...max)

    private static var max = UInt32(pow(2, 24.0))

    /// Returns the next value in the counter.
    func next() -> UInt32 {
        return queue.sync {
            self.count += 1
            // When the counter overflows (i.e., hits 16777215+1), the counter MUST be reset to 0.
            if self.count > ObjectIdCounter.max {
                self.count = 0
            }
            return self.count
        }
    }
}
