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

    /// Initializes a document from BSON `Data`. Throws an error if the BSON data is invalid.
    internal init(fromBSON data: Data) throws {
        guard data.count >= 5 else {
            throw InvalidBSONError("BSON documents must be at least 5 bytes long")
        }

        var lenBytes = data.subdata(in: 0..<4)
        let length = try Int32(from: &lenBytes)

        guard length == data.count else {
            throw InvalidBSONError("Document length is encoded as \(length) bytes, but provided data is \(data.count) bytes")
        }

        let lastByte = data.last!
        guard lastByte == 0 else {
            throw InvalidBSONError("Expected last byte to be null, got \(lastByte)")
        }

        self.data = data
    }

    /**
     * Allows setting values and retrieving values using subscript syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     *  ```
     * A nil return suggests that the subscripted key does not exist in the `Document`. A true BSON null is returned as
     * a `.null`.
     */
    public subscript(key: String) -> BSON? {
        get {
            return self.first { k, _ in k == key }.map { _, v in v }
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

    /**
     * An implementation identical to subscript(key: String), but offers the ability to choose a default value if the
     * key is missing.
     * For example:
     *  ```
     *  let d: Document = ["hello": "world"]
     *  print(d["hello", default: "foo"]) // prints "world"
     *  print(d["a", default: "foo"]) // prints "foo"
     *  ```
     */
    public subscript(key: String, default defaultValue: @autoclosure () -> BSON) -> BSON {
        return self[key] ?? defaultValue()
    }

    /**
     * Allows setting values and retrieving values using dot-notation syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d.a = 1
     *  print(d.a) // prints 1
     *  ```
     * A nil return suggests that the key does not exist in the `Document`. A true BSON null is returned as
     * a `.null`.
     *
     * Only available in Swift 4.2+.
     */
    @available(swift 4.2)
    public subscript(dynamicMember member: String) -> BSON? {
        get {
            return self[member]
        }
        set(newValue) {
            self[member] = newValue
        }
    }

    public var keys: [String] {
        return self.map { $0.0 }
    }

    public func hasKey(_ key: String) -> Bool {
        return self.keys.contains(key)
    }

    public var rawBSON: Data {
        return self.data
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

    internal var canonicalExtJSON: String {
        return "{ " + self.map { k, v in "\(k.canonicalExtJSON): \(v.canonicalExtJSON)" }.joined(separator: ", ") + " }"
    }

    internal var extJSON: String {
        return "{ " + self.map { k, v in "\(k.canonicalExtJSON): \(v.extJSON)" }.joined(separator: ", ") + " }"
    }

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
