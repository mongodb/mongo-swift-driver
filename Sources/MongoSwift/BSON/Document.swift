import Foundation
import libbson

/// A class representing the BSON document type
public class Document: ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
    internal var data: UnsafeMutablePointer<bson_t>!

    /// Returns a [String] containing the keys in this `Document`. 
    public var keys: [String] {
        var iter: bson_iter_t = bson_iter_t()
        if !bson_iter_init(&iter, data) { return [] }
        var keys = [String]()
        while bson_iter_next(&iter) {
            keys.append(String(cString: bson_iter_key(&iter)))
        }
        return keys
    }

    /// Returns a [BsonValue?] containing the values stored in this `Document`. 
    public var values: [BsonValue?] {
        var iter: bson_iter_t = bson_iter_t()
        if !bson_iter_init(&iter, data) { return [] }
        var values = [BsonValue?]()
        while bson_iter_next(&iter) {
            values.append(nextBsonValue(iter: &iter))
        }
        return values
    }

    /// Returns the number of (key, value) pairs stored at the top level
    /// of this document. 
    public var count: Int { return Int(bson_count_keys(self.data)) }

    /// Initialize a new, empty document
    public init() {
        data = bson_new()
    }

    /**
     * Initializes a `Document` from a pointer to a bson_t. Uses a copy
     * of `bsonData`, so the caller is responsible for freeing the original
     * memory. 
     * 
     * - Parameters:
     *   - bsonData: a UnsafeMutablePointer<bson_t>
     *
     * - Returns: a new `Document`
     */
    internal init(fromData bsonData: UnsafeMutablePointer<bson_t>) {
        data = bson_copy(bsonData)
    }

    /**
     * Initializes a `Document` from a [String: BsonValue?] 
     *
     * - Parameters:
     *   - doc: a [String: BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public init(_ doc: [String: BsonValue?]) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }

    /**
     * Initializes a `Document` using a dictionary literal where the 
     * keys are `String`s and the values are `BsonValue?`s. For example:
     * `d: Document = ["a" : 1 ]`
     *
     * - Parameters:
     *   - dictionaryLiteral: a [String: BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public required init(dictionaryLiteral doc: (String, BsonValue?)...) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }
    /**
     * Initializes a `Document` using an array literal where the values
     * are `BsonValue`s. Values are stored under a string of their 
     * index in the array. For example:
     * `d: Document = ["a", "b"]` will become `["0": "a", "1": "b"]`
     *
     * - Parameters:
     *   - arrayLiteral: a [BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public required init(arrayLiteral elements: BsonValue?...) {
        data = bson_new()
        for (i, elt) in elements.enumerated() {
            self[String(i)] = elt
        }
    }

    /**
     * Constructs a new `Document` from the provided JSON text
     *
     * - Parameters:
     *   - fromJSON: a JSON document as Data to parse into a `Document`
     *
     * - Returns: the parsed `Document`
     */
    public init(fromJSON: Data) throws {
        data = try fromJSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            var error = bson_error_t()
            guard let bson = bson_new_from_json(bytes, fromJSON.count, &error) else {
                throw MongoError.bsonParseError(
                    domain: error.domain,
                    code: error.code,
                    message: toErrorString(error)
                )
            }

            return bson
        }
    }

    /// Convenience initializer for constructing a `Document` from a `String`
    public convenience init(fromJSON json: String) throws {
        try self.init(fromJSON: json.data(using: .utf8)!)
    }

    /**
     * Constructs a `Document` from raw BSON data
     */
    public init(fromBSON: Data) {
        data = fromBSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            return bson_new_from_data(bytes, fromBSON.count)
        }
    }

    /// Returns a relaxed extended JSON representation of this Document
    var extendedJSON: String {
        let json = bson_as_relaxed_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

    /// Returns a canonical extended JSON representation of this Document
    var canonicalExtendedJSON: String {
        let json = bson_as_canonical_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

    /// Returns a copy of the raw BSON data represented as Data
    var rawBSON: Data {
        let data = bson_get_data(self.data)
        let length = self.data.pointee.len
        return Data(bytes: data!, count: Int(length))
    }

    deinit {
        guard let data = self.data else { return }
        bson_destroy(data)
        self.data = nil
    }

    /**
     * Allows setting values and retrieving values using subscript syntax.
     * For example:
     * 
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     * 
     */
    subscript(key: String) -> BsonValue? {
        get {
            var iter: bson_iter_t = bson_iter_t()
            if bson_iter_init_find(&iter, self.data, key.cString(using: .utf8)) {
                return nextBsonValue(iter: &iter)
            }
            return nil
        }

        set(newValue) {

            guard let value = newValue else {
                if !bson_append_null(data, key, Int32(key.count)) {
                    preconditionFailure("Failed to set the value for key \(key) to null")
                }
                return
            }

            do {
                try value.encode(to: data, forKey: key)
            } catch {
                preconditionFailure("Failed to set the value for key \(key) to \(value)")
            }

        }
    }

    /**
     * Allows retrieving and strongly typing a value at the same time. This means you can avoid
     * having to cast and unwrap values from the Document when you know what type they will be. 
     * For example:
     *      let d: Document = ["x": 1]
     *      let x: Int = try d.get("x")
     *
     *  - Params:
     *      - key: The key under which the value you are looking up is stored
     *      - T: Any type conforming to the `BsonValue` protocol
     *  - Returns:
     *      - The value stored under key, as type T 
     *  - Throws:
     *      - A MongoError.typeError if the value cannot be cast to type T or is not in the `Document`
     *
     */ 
    public func get<T: BsonValue>(_ key: String) throws -> T {
        guard let value = self[key] as? T else {
            throw MongoError.typeError(message: "Could not cast value for key \(key) to type \(T.self)")
        }
        return value
    }
}

extension Document: BsonValue {
    public var bsonType: BsonType { return .document }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_document(data, key, Int32(key.count), self.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public static func from(iter: inout bson_iter_t) -> BsonValue {
        var length: UInt32 = 0
        let document = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            document.deinitialize(count: 1)
            document.deallocate(capacity: 1)
        }

        bson_iter_document(&iter, &length, document)

        guard let docData = bson_new_from_data(document.pointee, Int(length)) else {
            preconditionFailure("Failed to create a bson_t from document data")
        }

        return Document(fromData: docData)
    }

}

/// An extension of `Document` to make it `Equatable`. 
extension Document: Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
        return bson_compare(lhs.data, rhs.data) == 0
    }
}

/// An extension of `Document` to make it convertible to a string.
extension Document: CustomStringConvertible {
    public var description: String {
        return self.extendedJSON
    }
}

/// An extension of `Document` to make it conform to the `Sequence` protocol.
/// This allows you to iterate through the (key, value) pairs, for example:
/// let doc: Document = ["a": 1, "b": 2]
/// for (key, value) in doc {
///     ...
/// }
extension Document: Sequence {
    public func makeIterator() -> DocumentIterator {
        return DocumentIterator(forDocument: self)
    }

    public class DocumentIterator: IteratorProtocol {
        internal var iter: bson_iter_t

        internal init(forDocument doc: Document) {
            self.iter = bson_iter_t()
            bson_iter_init(&self.iter, doc.data)
        }

        public func next() -> (String, BsonValue?)? {
            if bson_iter_next(&self.iter) {
                let key = String(cString: bson_iter_key(&self.iter))
                return (key, nextBsonValue(iter: &self.iter))
            }
            return nil
        }
    }
}
