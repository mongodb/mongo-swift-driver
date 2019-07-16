import Foundation

public struct PureBSONDocument {
    internal var data: Data

    private var byteLength: Int32 {
        get {
            var length: Int32 = 0
            _ = withUnsafeMutableBytes(of: &length) { ptr in
                self.data[0..<4].copyBytes(to: ptr)
            }
            return length
        }
        set(newLength) {
            withUnsafeBytes(of: newLength) { bytes in
                self.data[0..<4] = Data(bytes)
            }
        }
    }

    /// Initializes a new empty document.
    public init() {
        // length of an empty document is 5 bytes:
        // [ 4 bytes for Int32 length ] [ null byte ]
        self.data = Data(count: 5)
        self.updateLength()
    }

    internal init(elements: [(String, BSON)]) {
        // start off with 4 empty bytes to hold the length. we will come back and fill in later.
        self.data = Data(count: 4)
        defer { self.updateLength() }

        for (key, value) in elements {
            data.append(value.bsonType)
            data.append(key.toCStringData())
            data.append(value.toBSON())
        }

        data.append(0)
    }

    internal mutating func updateLength() {
        self.byteLength = Int32(self.data.count)
    }
}

extension PureBSONDocument: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self.init(elements: elements)
    }
}

extension PureBSONDocument: PureBSONValue {
    internal init(from data: Data) throws {
        // should we do any validation here?
        self.data = data
    }
    
    internal func toBSON() -> Data {
        return self.data
    }
}

extension PureBSONDocument: Equatable {}
extension PureBSONDocument: Hashable {}

extension PureBSONDocument: CustomStringConvertible {
    public var description: String {
        let equivalentDoc = Document(fromBSON: self.data)
        return equivalentDoc.description
    }
}
