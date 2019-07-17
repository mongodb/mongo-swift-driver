import Foundation

/// Internals
public struct PureBSONDocument {
    internal var data: Data

    private var byteLength: Int32 {
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
        self.byteLength = Int32(self.data.count)
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


            // guard self.byteLength > 5 else {
            //     return nil
            // }

            // // first byte of the first ename.
            // var idx = 5
            // while true {
            //     // we've reached the end of the doc.
            //     if idx >= self.byteLength - 1 {
            //         return nil
            //     }

            //     // read the next key.
            //     let keyName = String(cStringData: self.data[idx...])
            //     guard keyName == key else {
            //         let bsonType = self.data[idx - 1]
            //         idx += keyName.utf.count + 1
            //         switch bsonType {
            //         // undefined, null, minkey, maxkey are 0 bytes
            //         case 0x06, 0x0A, 0xFF, 0x7F:
            //             idx += 0
            //         // boolean
            //         case 0x08:
            //             idx += 1
            //         // int32
            //         case 0x10:
            //             idx += 4
            //         // double, int64, uint64 are 8 bytes
            //         case 0x01, 0x09, 0x11:
            //             idx += 8
            //         // string, document, array
            //         case 0x02, 0x03, 0x04:
            //             idx += 0 // todo get len
            //         // binary
            //         case 0x05:
            //             idx += 0 // get binsry len

            //         }
            //     }

            //     // read value out here
            //     return nil
            // }
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
extension PureBSONDocument: Codable {}
