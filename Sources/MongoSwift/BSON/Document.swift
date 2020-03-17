import CLibMongoC
import Foundation

#if compiler(>=5.0)
internal typealias BSONPointer = OpaquePointer
internal typealias MutableBSONPointer = OpaquePointer
#else
internal typealias BSONPointer = UnsafePointer<bson_t>
internal typealias MutableBSONPointer = UnsafeMutablePointer<bson_t>
#endif

/// The storage backing a MongoSwift `Document`.
public class DocumentStorage {
    internal var _bson: MutableBSONPointer!

    /// Initializes a new, empty `DocumentStorage`.
    internal init() {
        self._bson = bson_new()
    }

    /// Initializes a new `DocumentStorage` by copying over the data from the provided `bson_t`.
    internal init(copying pointer: BSONPointer) {
        self._bson = bson_copy(pointer)
    }

    /// Initializes a new `DocumentStorage` that uses the provided `bson_t` as its backing storage.
    /// The newly created instance will handle cleaning up the pointer upon deinitialization.
    internal init(stealing pointer: MutableBSONPointer) {
        self._bson = pointer
    }

    /// Cleans up internal state.
    deinit {
        guard let bson = self._bson else {
            return
        }

        bson_destroy(bson)
        self._bson = nil
    }
}

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct Document {
    /// Error thrown when calls to bson_new return a null pointer.
    internal static let InvalidBSONError = InternalError(message: "Invalid BSON data")

    /// Error thrown when BSON buffer is too small.
    internal static let BsonBufferTooSmallError =
        InternalError(message: "BSON buffer is unexpectedly too small (< 5 bytes)")

    /// the storage backing this document.
    internal var _storage: DocumentStorage
}

/// An extension of `Document` containing its private/internal functionality.
extension Document {
    /// Read-only access to the storage's underlying bson_t.
    internal var _bson: BSONPointer {
#if compiler(>=5.0)
        return self._storage._bson
#else
        return UnsafePointer(self._storage._bson)
#endif
    }

    /**
     * Initializes a `Document` from a pointer to a `bson_t` by making a copy of the data. The `bson_t`'s owner is
     * responsible for freeing the original.
     *
     * - Parameters:
     *   - pointer: a BSONPointer
     *
     * - Returns: a new `Document`
     */
    internal init(copying pointer: BSONPointer) {
        self._storage = DocumentStorage(copying: pointer)
    }

    /**
     * Initializes a `Document` from a pointer to a `bson_t`, "stealing" the `bson_t` to use for underlying storage/
     * The `bson_t` must not be modified or freed by others after it is used here.
     *
     * - Parameters:
     *   - pointer: a MutableBSONPointer
     *
     * - Returns: a new `Document`
     */
    internal init(stealing pointer: MutableBSONPointer) {
        self._storage = DocumentStorage(stealing: pointer)
    }

    /**
     * Initializes a `Document` using an array where the values are KeyValuePairs.
     *
     * - Parameters:
     *   - elements: a `[KeyValuePair]`
     *
     * - Returns: a new `Document`
     */
    internal init(_ elements: [KeyValuePair]) {
        self._storage = DocumentStorage()
        for (key, value) in elements {
            do {
                try self.setValue(for: key, to: value)
            } catch {
                fatalError("Failed to set the value for \(key) to \(String(describing: value)): \(error)")
            }
        }
    }

    /**
     * Initializes a `Document` using an array where the values are optional
     * `BSON`s. Values are stored under a string of their index in the
     * array.
     *
     * - Parameters:
     *   - elements: a `[BSON]`
     *
     * - Returns: a new `Document`
     */
    internal init(_ elements: [BSON]) {
        self._storage = DocumentStorage()
        for (i, elt) in elements.enumerated() {
            do {
                try self.setValue(for: String(i), to: elt, checkForKey: false)
            } catch {
                fatalError("Failed to set the value for index \(i) to \(String(describing: elt)): \(error)")
            }
        }
    }

    /**
     * Sets key to newValue. if checkForKey=false, the key/value pair will be appended without checking for the key's
     * presence first.
     *
     * - Throws:
     *   - `InternalError` if the new value is an `Int` and cannot be written to BSON.
     *   - `LogicError` if the new value is a `Decimal128` or `ObjectId` and is improperly formatted.
     *   - `LogicError` if the new value is an `Array` and it contains a non-`BSONValue` element.
     *   - `InternalError` if the `DocumentStorage` would exceed the maximum size by encoding this
     *     key-value pair.
     */
    internal mutating func setValue(for key: String, to newValue: BSON, checkForKey: Bool = true) throws {
        let newBSONValue = newValue.bsonValue

        // if the key already exists in the `Document`, we need to replace it
        if checkForKey, let existingType = DocumentIterator(forDocument: self, advancedTo: key)?.currentType {
            let newBSONType = newBSONValue.bsonType
            let sameTypes = newBSONType == existingType

            // if the new type is the same and it's a type with no custom data, no-op
            if sameTypes && [.null, .undefined, .minKey, .maxKey].contains(newBSONType) {
                return
            }

            // if the new type is the same and it's a fixed length type, we can overwrite
            if let ov = newBSONValue as? Overwritable, ov.bsonType == existingType {
                self.copyStorageIfRequired()
                // key is guaranteed present so initialization will succeed.
                // swiftlint:disable:next force_unwrapping
                try DocumentIterator(forDocument: self, advancedTo: key)!.overwriteCurrentValue(with: ov)

                // otherwise, we just create a new document and replace this key
            } else {
                guard let iter = DocumentIterator(forDocument: self) else {
                    throw Document.BsonBufferTooSmallError
                }

                var keysBefore: [String] = []
                var keysAfter: [String] = []
                var seen = false

                while let next = iter.next() {
                    if next.key == key {
                        seen = true
                        keysBefore.append(next.key)
                        keysAfter.append(next.key)
                    } else {
                        seen ? keysAfter.append(next.key) : keysBefore.append(next.key)
                    }
                }

                // To preserve order, we construct a Document excluding keys before the key and a Document excluding
                // keys after the key. We then merge both Documents and appropriately set the new value for the key.
                guard let bson = bson_new() else {
                    throw Document.InvalidBSONError
                }

                try DocumentIterator.copyElements(from: self._bson, to: bson, excluding: keysAfter)
                var newSelf = Document(stealing: bson)
                try newSelf.setValue(for: key, to: newValue)
                try DocumentIterator.copyElements(from: self._bson, to: newSelf._bson, excluding: keysBefore)
                self = newSelf
            }

            // otherwise, it's a new key
        } else {
            self.copyStorageIfRequired()
            try newBSONValue.encode(to: self._storage, forKey: key)
        }
    }

    /// Retrieves the value associated with `for` as a `BSON?`, which can be nil if the key does not exist in the
    /// `Document`.
    ///
    /// - Throws: `InternalError` if the BSON buffer is too small (< 5 bytes).
    internal func getValue(for key: String) throws -> BSON? {
        guard let iter = DocumentIterator(forDocument: self) else {
            throw Document.BsonBufferTooSmallError
        }

        guard iter.move(to: key) else {
            return nil
        }

        return try iter.safeCurrentValue()
    }

    /// Appends the key/value pairs from the provided `doc` to this `Document`.
    /// Note: This function does not check for or clean away duplicate keys.
    internal mutating func merge(_ doc: Document) throws {
        let success = withMutableBSONPointer(to: &self) { selfPtr in
            bson_concat(selfPtr, doc._bson)
        }
        guard success else {
            throw InternalError(
                message: "Failed to merge \(doc) with \(self). This is likely due to " +
                    "the merged document being too large."
            )
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
     *      doc2.setValue(forKey: "b", to: 2)
     *
     * Therefore, this function should be called just before we are about to modify a document - either by
     * setting a value or merging in another doc.
     */
    fileprivate mutating func copyStorageIfRequired() {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = DocumentStorage(copying: self._bson)
        }
    }

    /// If the document already has an _id, returns it as-is. Otherwise, returns a new document
    /// containing all the keys from this document, with an _id prepended.
    internal func withID() throws -> Document {
        if self.hasKey("_id") {
            return self
        }

        var idDoc: Document = ["_id": .objectId(ObjectId())]
        try idDoc.merge(self)
        return idDoc
    }
}

/// An extension of `Document` containing its public API.
extension Document {
    /// Returns a `[String]` containing the keys in this `Document`.
    public var keys: [String] {
        return self.makeIterator().keys
    }

    /// Returns a `[BSON]` containing the values stored in this `Document`.
    public var values: [BSON] {
        return self.makeIterator().values
    }

    /// Returns the number of (key, value) pairs stored at the top level of this `Document`.
    public var count: Int {
        return Int(bson_count_keys(self._bson))
    }

    /// Returns the relaxed extended JSON representation of this `Document`.
    /// On error, an empty string will be returned.
    public var extendedJSON: String {
        guard let json = bson_as_relaxed_extended_json(self._bson, nil) else {
            return ""
        }

        defer {
            bson_free(json)
        }

        return String(cString: json)
    }

    /// Returns the canonical extended JSON representation of this `Document`.
    /// On error, an empty string will be returned.
    public var canonicalExtendedJSON: String {
        guard let json = bson_as_canonical_extended_json(self._bson, nil) else {
            return ""
        }

        defer {
            bson_free(json)
        }

        return String(cString: json)
    }

    /// Returns a copy of the raw BSON data for this `Document`, represented as `Data`.
    public var rawBSON: Data {
        // swiftlint:disable:next force_unwrapping
        let data = bson_get_data(self._bson)! // documented as always returning a value.

        /// BSON encodes the length in the first four bytes, so we can read it in from the
        /// raw data without needing to access the `len` field of the `bson_t`.
        let length = data.withMemoryRebound(to: Int32.self, capacity: 4) { $0.pointee }

        return Data(bytes: data, count: Int(length))
    }

    /// Initializes a new, empty `Document`.
    public init() {
        self._storage = DocumentStorage()
    }

    internal init(keyValuePairs: [(String, BSON)]) {
        // make sure all keys are unique
        guard Set(keyValuePairs.map { $0.0 }).count == keyValuePairs.count else {
            fatalError("Dictionary literal \(keyValuePairs) contains duplicate keys")
        }

        self._storage = DocumentStorage()
        for (key, value) in keyValuePairs {
            do {
                try self.setValue(for: key, to: value, checkForKey: false)
            } catch {
                fatalError("Error setting key \(key) to value \(String(describing: value)): \(error)")
            }
        }
    }

    /**
     * Constructs a new `Document` from the provided JSON text.
     *
     * - Parameters:
     *   - fromJSON: a JSON document as `Data` to parse into a `Document`
     *
     * - Returns: the parsed `Document`
     *
     * - Throws:
     *   - A `InvalidArgumentError` if the data passed in is invalid JSON.
     */
    public init(fromJSON: Data) throws {
        self._storage = DocumentStorage(stealing: try fromJSON.withUnsafeBytePointer { bytes in
            var error = bson_error_t()
            guard let bson = bson_new_from_json(bytes, fromJSON.count, &error) else {
                if error.domain == BSON_ERROR_JSON {
                    throw InvalidArgumentError(message: "Invalid JSON: \(toErrorString(error))")
                }
                throw InternalError(message: toErrorString(error))
            }

            return bson
        })
    }

    /// Convenience initializer for constructing a `Document` from a `String`.
    /// - Throws:
    ///   - A `InvalidArgumentError` if the string passed in is invalid JSON.
    public init(fromJSON json: String) throws {
        // `String`s are Unicode under the hood so force unwrap always succeeds.
        // see https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        try self.init(fromJSON: json.data(using: .utf8)!) // swiftlint:disable:this force_unwrapping
    }

    /**
     * Constructs a `Document` from raw BSON `Data`.
     * - Throws:
     *   - A `InvalidArgumentError` if `bson` is too short or too long to be valid BSON.
     *   - A `InvalidArgumentError` if the first four bytes of `bson` do not contain `bson.count`.
     *   - A `InvalidArgumentError` if the final byte of `bson` is not a null byte.
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: Data) throws {
        self._storage = DocumentStorage(stealing: try bson.withUnsafeBytePointer { bytes in
            guard let data = bson_new_from_data(bytes, bson.count) else {
                throw InvalidArgumentError(message: "Invalid BSON data")
            }
            return data
        })
    }

    /// Returns a `Boolean` indicating whether this `Document` contains the provided key.
    public func hasKey(_ key: String) -> Bool {
        return bson_has_field(self._bson, key)
    }

    /**
     * Allows setting values and retrieving values using subscript syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     *  ```
     * A nil return value indicates that the subscripted key does not exist in the `Document`. A true BSON null is
     * returned as `BSON.null`.
     */
    public subscript(key: String) -> BSON? {
        // TODO: This `get` method _should_ guarantee constant-time O(1) access, and it is possible to make it do so.
        // This criticism also applies to indexed-based subscripting via `Int`.
        // See SWIFT-250.
        get { return DocumentIterator(forDocument: self, advancedTo: key)?.currentValue }
        set(newValue) {
            do {
                if let newValue = newValue {
                    try self.setValue(for: key, to: newValue)
                } else {
                    guard let bson = bson_new() else {
                        fatalError(Document.InvalidBSONError.message)
                    }
                    try DocumentIterator.copyElements(from: self._bson, to: bson, excluding: [key])
                    self = Document(stealing: bson)
                }
            } catch {
                fatalError("Failed to set the value for key \(key) to \(newValue ?? "nil"): \(error)")
            }
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
     * A nil return value indicates that the key does not exist in the `Document`. A true BSON null is returned as
     * `BSON.null`.
     */
    public subscript(dynamicMember member: String) -> BSON? {
        get {
            return self[member]
        }
        set(newValue) {
            self[member] = newValue
        }
    }
}

/// An extension of `Document` to make it a `BSONValue`.
extension Document: BSONValue {
    internal static var bsonType: BSONType { return .document }

    internal var bson: BSON { return .document(self) }

    internal func encode(to storage: DocumentStorage, forKey key: String) throws {
        guard bson_append_document(storage._bson, key, Int32(key.utf8.count), self._bson) else {
            throw bsonTooLargeError(value: self, forKey: key)
        }
    }

    internal static func from(iterator iter: DocumentIterator) throws -> BSON {
        guard iter.currentType == .document else {
            throw wrongIterTypeError(iter, expected: Document.self)
        }

        return .document(try iter.withBSONIterPointer { iterPtr in
            var length: UInt32 = 0
            let document = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
            defer {
                document.deinitialize(count: 1)
                document.deallocate()
            }

            bson_iter_document(iterPtr, &length, document)

            guard let docData = bson_new_from_data(document.pointee, Int(length)) else {
                throw InternalError(message: "Failed to create a Document from iterator")
            }

            return self.init(stealing: docData)
        })
    }
}

/// An extension of `Document` to make it `Equatable`.
extension Document: Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
        return bson_compare(lhs._bson, rhs._bson) == 0
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

/// An extension of `Document` to add the capability to be initialized with a dictionary literal.
extension Document: ExpressibleByDictionaryLiteral {
    /**
     * Initializes a `Document` using a dictionary literal where the
     * keys are `String`s and the values are `BSON`s. For example:
     * `d: Document = ["a" : 1 ]`
     *
     * - Parameters:
     *   - dictionaryLiteral: a [String: BSON]
     *
     * - Returns: a new `Document`
     */
    public init(dictionaryLiteral keyValuePairs: (String, BSON)...) {
        self.init(keyValuePairs: keyValuePairs)
    }
}

/// Executes the provided closure using a mutable pointer to the document's underlying storage.
internal func withMutableBSONPointer<T>(
    to document: inout Document,
    body: (MutableBSONPointer) throws -> T
) rethrows -> T {
    document.copyStorageIfRequired()
    return try body(document._storage._bson)
}

// An extension of `Document` to add the capability to be hashed
extension Document: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawBSON)
    }
}

extension Data {
    /// Gets access to the start of the data buffer in the form of an UnsafePointer<UInt8>?. Useful for calling C API
    /// methods that expect the location of an uint8_t. The pointer provided to `body` will be null if the `Data` has
    /// count == 0.
    /// Based on https://mjtsai.com/blog/2019/03/27/swift-5-released/
    fileprivate func withUnsafeBytePointer<T>(body: (UnsafePointer<UInt8>?) throws -> T) rethrows -> T {
        return try self.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let bufferPtr = rawPtr.bindMemory(to: UInt8.self)
            let bytesPtr = bufferPtr.baseAddress
            return try body(bytesPtr)
        }
    }
}
