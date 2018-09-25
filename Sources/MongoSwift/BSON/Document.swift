import Foundation
import libbson

/// The storage backing a MongoSwift `Document`.
public class DocumentStorage {
    internal var pointer: UnsafeMutablePointer<bson_t>!

    init() {
        self.pointer = bson_new()
    }

    init(fromPointer pointer: UnsafePointer<bson_t>) {
        self.pointer = bson_copy(pointer)
    }

    deinit {
        guard let pointer = self.pointer else { return }
        bson_destroy(pointer)
        self.pointer = nil
    }
}

/// A struct representing the BSON document type.
public struct Document: ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
    /// the storage backing this document 
    internal var storage: DocumentStorage

    /// direct access to the storage's pointer to a bson_t
    internal var data: UnsafeMutablePointer<bson_t>! { return storage.pointer }

    /// Returns a `[String]` containing the keys in this `Document`.
    public var keys: [String] {
        return self.makeIterator().keys
    }

    /// Returns a `Boolean` indicating whether this `Document` contains the provided key.
    public func hasKey(_ key: String) -> Bool {
        return bson_has_field(self.data, key)
    }

    /// Returns a `[BsonValue?]` containing the values stored in this `Document`.
    public var values: [BsonValue?] {
        return self.makeIterator().values
    }

    /// Initializes a new, empty `Document`.
    public init() {
        self.storage = DocumentStorage()
    }

    /**
     * Initializes a `Document` from a pointer to a bson_t. Uses a copy
     * of `bsonData`, so the caller is responsible for freeing the original
     * memory.
     *
     * - Parameters:
     *   - fromPointer: a UnsafePointer<bson_t>
     *
     * - Returns: a new `Document`
     */
    internal init(fromPointer pointer: UnsafePointer<bson_t>) {
        self.storage = DocumentStorage(fromPointer: pointer)
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
    public init(dictionaryLiteral keyValuePairs: (String, BsonValue?)...) {
        // make sure all keys are unique
        if Set(keyValuePairs.map { $0.0 }).count != keyValuePairs.count {
            preconditionFailure("Dictionary literal \(keyValuePairs) contains duplicate keys")
        }

        self.storage = DocumentStorage()
        for (key, value) in keyValuePairs {
            do {
                try self.setValue(forKey: key, to: value, checkForKey: false)
            } catch {
                preconditionFailure("Error setting key \(key) to value \(String(describing: value)): \(error)")
            }
        }
    }
    /**
     * Initializes a `Document` using an array literal where the values
     * are `BsonValue`s. Values are stored under a string of their
     * index in the array. For example:
     * `d: Document = ["a", "b"]` will become `["0": "a", "1": "b"]`
     *
     * - Parameters:
     *   - arrayLiteral: a `[BsonValue?]`
     *
     * - Returns: a new `Document`
     */
    public init(arrayLiteral elements: BsonValue?...) {
        self.init(elements)
    }

    /**
     * Initializes a `Document` using an array where the values are optional
     * `BsonValue`s. Values are stored under a string of their index in the
     * array.
     *
     * - Parameters:
     *   - elements: a `[BsonValue?]`
     *
     * - Returns: a new `Document`
     */
    internal init(_ elements: [BsonValue?]) {
        self.storage = DocumentStorage()
        for (i, elt) in elements.enumerated() {
            do {
                try self.setValue(forKey: String(i), to: elt, checkForKey: false)
            } catch {
                preconditionFailure("Failed to set the value for index \(i) to \(String(describing: elt)): \(error)")
            }
        }
    }

    /**
     * Constructs a new `Document` from the provided JSON text
     *
     * - Parameters:
     *   - fromJSON: a JSON document as `Data` to parse into a `Document`
     *
     * - Returns: the parsed `Document`
     */
    public init(fromJSON: Data) throws {
        self.storage = DocumentStorage(fromPointer: try fromJSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            var error = bson_error_t()
            guard let bson = bson_new_from_json(bytes, fromJSON.count, &error) else {
                throw MongoError.bsonParseError(
                    domain: error.domain,
                    code: error.code,
                    message: toErrorString(error)
                )
            }

            return UnsafePointer(bson)
        })
    }

    /// Convenience initializer for constructing a `Document` from a `String`
    public init(fromJSON json: String) throws {
        try self.init(fromJSON: json.data(using: .utf8)!)
    }

    /// Constructs a `Document` from raw BSON `Data`
    public init(fromBSON: Data) {
        self.storage = DocumentStorage(fromPointer: fromBSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            bson_new_from_data(bytes, fromBSON.count)
        })
    }

    /// Returns the relaxed extended JSON representation of this `Document`.
    /// On error, an empty string will be returned.
    public var extendedJSON: String {
        guard let json = bson_as_relaxed_extended_json(self.data, nil) else {
            return ""
        }

        return String(cString: json)
    }

    /// Returns the canonical extended JSON representation of this `Document`.
    /// On error, an empty string will be returned.
    public var canonicalExtendedJSON: String {
        guard let json = bson_as_canonical_extended_json(self.data, nil) else {
            return ""
        }

        return String(cString: json)
    }

    /// Returns a copy of the raw BSON data for this `Document`, represented as `Data`
    public var rawBSON: Data {
        let data = bson_get_data(self.data)
        let length = self.data.pointee.len
        return Data(bytes: data!, count: Int(length))
    }

    /**
     * Allows setting values and retrieving values using subscript syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     *  ```
     */
    public subscript(key: String) -> BsonValue? {
        get { return DocumentIterator(forDocument: self, advancedTo: key)?.currentValue }
        set(newValue) {
            do {
                try self.setValue(forKey: key, to: newValue)
            } catch {
                preconditionFailure("Failed to set the value for key \(key) to \(newValue ?? "nil"): \(error)")
            }
        }
    }

    /// Sets key to newValue. if checkForKey=false, the key/value pair will be appended without checking for the key's presence first.
    private mutating func setValue(forKey key: String, to newValue: BsonValue?, checkForKey: Bool = true) throws {
        // if the key already exists in the `Document`, we need to replace it
        if checkForKey, let existingType = DocumentIterator(forDocument: self, advancedTo: key)?.currentType {

            let newBsonType = newValue?.bsonType ?? .null
            let sameTypes = newBsonType == existingType

            // if the new type is the same and it's a type with no custom data, no-op
            if sameTypes && [.null, .undefined, .minKey, .maxKey].contains(newBsonType) { return }

            // if the new type is the same and it's a fixed length type, we can overwrite
            if let ov = newValue as? Overwritable, ov.bsonType == existingType {
                self.copyStorageIfRequired()
                // make a new iterator referencing our new storage. we already know the key is present
                /// so initialization will succeed and ! is safe.
                try DocumentIterator(forDocument: self, advancedTo: key)!.overwriteCurrentValue(with: ov)

            // otherwise, we just create a new document and replace this key
            } else {
                // TODO SWIFT-224: use va_list variant of bson_copy_to_excluding to improve performance
                var newSelf = Document()
                var seen = false
                try self.forEach { pair in
                    if !seen && pair.key == key {
                        seen = true
                        try newSelf.setValue(forKey: pair.key, to: newValue)
                    } else {
                        try newSelf.setValue(forKey: pair.key, to: pair.value)
                    }
                }
                self = newSelf
            }

        // otherwise, it's a new key
        } else {
            self.copyStorageIfRequired()

            if let value = newValue {
                try value.encode(to: self.storage, forKey: key)
            } else if !bson_append_null(self.data, key, Int32(key.count)) {
                throw MongoError.bsonEncodeError(message: "Failed to set the value for key \(key) to null")
            }
        }
    }

    /**
     * Allows retrieving and strongly typing a value at the same time. This means you can avoid
     * having to cast and unwrap values from the `Document` when you know what type they will be.
     * For example:
     * ```
     *  let d: Document = ["x": 1]
     *  let x: Int = try d.get("x")
     *  ```
     *
     *  - Parameters:
     *      - key: The key under which the value you are looking up is stored
     *      - `T`: Any type conforming to the `BsonValue` protocol
     *  - Returns: The value stored under key, as type `T`
     *  - Throws: A `MongoError.typeError` if the value cannot be cast to type `T` or is not in the `Document`
     *
     */
    public func get<T: BsonValue>(_ key: String) throws -> T {
        guard let value = self[key] as? T else {
            throw MongoError.typeError(message: "Could not cast value for key \(key) to type \(T.self)")
        }
        return value
    }

    /// Appends the key/value pairs from the provided `doc` to this `Document`. 
    public mutating func merge(_ doc: Document) throws {
        self.copyStorageIfRequired()
        if !bson_concat(self.data, doc.data) {
            throw MongoError.bsonEncodeError(message: "Failed to merge \(doc) with \(self)")
        }
    }

    /**
     * Checks if the document is uniquely referenced. If not, makes a copy of the underlying `bson_t`
     * and lets the copy/copies keep the original. This allows us to provide value semantics for `Document`s.
     * This happens if someone copies a document and modifies it.
     * 
     * For example:
     *      let doc1: Document = ["a": 1]
     *      var doc2 = doc1
     *      doc2["b"] = 2
     *
     * Therefore, this function should be called just before we are about to modify a document - either by
     * setting a value or merging in another doc.
     */
    private mutating func copyStorageIfRequired() {
        if !isKnownUniquelyReferenced(&self.storage) {
            self.storage = DocumentStorage(fromPointer: self.data)
        }
    }
}

/// An extension of `Document` to make it a `BsonValue`.
extension Document: BsonValue {
    public var bsonType: BsonType { return .document }

    public func encode(to storage: DocumentStorage, forKey key: String) throws {
        if !bson_append_document(storage.pointer, key, Int32(key.count), self.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public init(from iter: DocumentIterator) throws {
        var length: UInt32 = 0
        let document = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
        defer {
            document.deinitialize(count: 1)
            document.deallocate(capacity: 1)
        }

        bson_iter_document(&iter.iter, &length, document)

        guard let docData = bson_new_from_data(document.pointee, Int(length)) else {
            throw MongoError.bsonDecodeError(message: "Failed to create a bson_t from document data")
        }

        self.init(fromPointer: docData)
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
    /// Returns the relaxed extended JSON representation of this `Document`.
    /// On error, an empty string will be returned.
    public var description: String {
        return self.extendedJSON
    }
}
