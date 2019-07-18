import Foundation

/// Internals
public struct PureBSONDocument {
    internal var data: Data

    internal var byteCount: Int32 {
        get {
            return Int32(self.data.count)
        }
        set(newLength) {
            withUnsafeBytes(of: newLength) { bytes in
                self.data[0..<4] = Data(bytes)
            }
        }
    }

    private mutating func updateLength() {
        self.byteCount = Int32(self.data.count)
    }

    internal init(elements: [(String, BSON)]) {
        // length of an empty document is 5 bytes:
        // [ 4 bytes for Int32 length ] [ null byte ]
        self.data = Data(count: 5)
        for (key, value) in elements {
            self[key] = value
        }
    }

    public var keys: [String] {
        // TODO: fill this in for real
        let libbsonDocument = Document(fromBSON: self.data)
        return libbsonDocument.keys
    }

    public func hasKey(_ key: String) -> Bool {
        return self.keys.contains(key)
    }
}

/// Public API
extension PureBSONDocument {
    /// Initializes a new empty document.
    public init() {
        // length of an empty document is 5 bytes:
        // [ 4 bytes for Int32 length ] [ null byte ]
        self.data = Data(count: 5)
        self.updateLength()
    }

    public subscript(key: String) -> BSON? {
        get {
            let libbsonDoc = Document(fromBSON: self.data)
            guard let value = libbsonDoc[key] else { return nil }
            // Int doesn't conform to PureBSONValue
            if let intVal = value as? Int {
                return .int64(Int64(intVal))
            }
            guard let asPureBSON = value as? PureBSONValue else {
                fatalError("couldn't cast value to PureBSONValue")
            }
            return asPureBSON.bson
        }
        set(newValue) {
            guard let value = newValue else {
                // TODO: remove value from doc
                return
            }

            self.data[self.data.count - 1] = value.bsonType
            self.data.append(key.toCStringData())
            self.data.append(value.toBSON())
            self.data.append(0)
            self.updateLength()
        }
    }
}

extension PureBSONDocument: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self.init(elements: elements)
    }
}

extension PureBSONDocument: PureBSONValue {
    internal static var bsonType: BSONType { return .document }

    internal var bson: BSON { return .document(self) }

    internal init(from data: inout Data) throws {
        guard data.count >= 5 else {
            throw RuntimeError.internalError(message: "expected to get at least 5 bytes, got \(data.count)")
        }
        // should we do any validation here?
        let copy = data
        let length = Int(try Int32(from: &data))
        self.data = copy.subdata(in: copy.startIndex..<(copy.startIndex + length))
        data.removeFirst(length - 4)
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
extension PureBSONDocument: Codable {}
