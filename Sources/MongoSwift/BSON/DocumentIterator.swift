import Foundation
import mongoc

#if compiler(>=5.0)
internal typealias BSONIterPointer = OpaquePointer
internal typealias MutableBSONIterPointer = OpaquePointer
#else
internal typealias BSONIterPointer = UnsafePointer<bson_iter_t>
internal typealias MutableBSONIterPointer = UnsafeMutablePointer<bson_iter_t>
#endif

/// An iterator over the values in a `Document`.
public class DocumentIterator: IteratorProtocol {
    /// the libbson iterator. it must be a `var` because we use it as
    /// an inout argument
    internal var _iter: bson_iter_t
    /// a reference to the storage for the document we're iterating
    internal let _storage: DocumentStorage

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if the key is not
    /// found, or if an iterator cannot be created over `doc` due to an error from e.g. corrupt data.
    internal init?(forDocument doc: Document) {
        self._iter = bson_iter_t()
        self._storage = doc._storage

        let initialized = self.withMutableBSONIterPointer { iterPtr in
            bson_iter_init(iterPtr, doc._bson)
        }

        guard initialized else {
            return nil
        }
    }

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if an iterator cannot
    /// be created over `doc` due to an error from e.g. corrupt data, or if the key is not found.
    internal init?(forDocument doc: Document, advancedTo key: String) {
        self._iter = bson_iter_t()
        self._storage = doc._storage

        let initialized = self.withMutableBSONIterPointer { iterPtr in
            bson_iter_init_find(iterPtr, doc._bson, key.cString(using: .utf8))
        }

        guard initialized else {
            return nil
        }
    }

    /// Advances the iterator forward one value. Returns false if there is an error moving forward
    /// or if at the end of the document. Returns true otherwise.
    internal func advance() -> Bool {
        return self.withMutableBSONIterPointer { iterPtr in
          bson_iter_next(iterPtr)
        }
    }

    /// Moves the iterator to the specified key. Returns false if the key does not exist. Returns true otherwise.
    internal func move(to key: String) -> Bool {
        return self.withMutableBSONIterPointer { iterPtr in
          bson_iter_find(iterPtr, key.cString(using: .utf8))
        }
    }

    /// Returns the current key. Assumes the iterator is in a valid position.
    internal var currentKey: String {
        return self.withBSONIterPointer { iterPtr in
          String(cString: bson_iter_key(iterPtr))
        }
    }

    /// Returns the current value. Assumes the iterator is in a valid position.
    internal var currentValue: BSONValue {
        do {
            return try self.safeCurrentValue()
        } catch { // Since properties cannot throw, we need to catch and raise a fatalError.
            fatalError("Error getting current value from iterator: \(error)")
        }
    }

    /// Returns the current value's type. Assumes the iterator is in a valid position.
    internal var currentType: BSONType {
        return self.withBSONIterPointer { iterPtr in
          BSONType(rawValue: bson_iter_type(iterPtr).rawValue) ?? .invalid
        }
    }

    /// Returns the keys from the iterator's current position to the end. The iterator
    /// will be exhausted after this property is accessed.
    internal var keys: [String] {
        var keys = [String]()
        while self.advance() { keys.append(self.currentKey) }
        return keys
    }

    /// Returns the values from the iterator's current position to the end. The iterator
    /// will be exhausted after this property is accessed.
    internal var values: [BSONValue] {
        var values = [BSONValue]()
        while self.advance() { values.append(self.currentValue) }
        return values
    }

    /// Returns the current value (equivalent to the `currentValue` property) or throws on error.
    ///
    /// - Throws:
    ///   - `RuntimeError.internalError` if the current value of this `DocumentIterator` cannot be decoded to BSON.
    internal func safeCurrentValue() throws -> BSONValue {
        guard let bsonType = DocumentIterator.bsonTypeMap[currentType] else {
            throw RuntimeError.internalError(
                    message: "Unknown BSONType for iterator's current value with type: \(currentType)"
            )
        }

        return try bsonType.from(iterator: self)
    }

    // uses an iterator to copy (key, value) pairs of the provided document from range [startIndex, endIndex) into a new
    // document. starts at the startIndex-th pair and ends at the end of the document or the (endIndex-1)th index,
    // whichever comes first.
    internal static func subsequence(of doc: Document, startIndex: Int = 0, endIndex: Int = Int.max) -> Document {
        guard endIndex >= startIndex else {
            fatalError("endIndex must be >= startIndex")
        }

        guard let iter = DocumentIterator(forDocument: doc) else {
            return [:]
        }

        // skip the values preceding startIndex. this is more performant than calling next, because
        // it doesn't pull the unneeded key/values out of the iterator
        for _ in 0..<startIndex { _ = iter.advance() }

        var output = Document()

        // TODO SWIFT-224: use va_list variant of bson_copy_to_excluding to improve performance
        for _ in startIndex..<endIndex {
            if let next = iter.next() {
                output[next.key] = next.value
            } else {
                // we ran out of values
                break
            }
        }

        return output
    }

    /// Returns the next value in the sequence, or `nil` if the iterator is exhausted.
    public func next() -> Document.KeyValuePair? {
        return self.advance() ? (self.currentKey, self.currentValue) : nil
    }

    /**
     * Overwrites the current value of this `DocumentIterator` with the supplied value.
     *
     * - Throws:
     *   - `RuntimeError.internalError` if the new value is an `Int` and cannot be written to BSON.
     *   - `UserError.logicError` if the new value is a `Decimal128` or `ObjectId` and is improperly formatted.
     */
    internal func overwriteCurrentValue(with newValue: Overwritable) throws {
        guard newValue.bsonType == self.currentType else {
            fatalError("Expected \(newValue) to have BSON type \(self.currentType), but has type \(newValue.bsonType)")
        }
        try newValue.writeToCurrentPosition(of: self)
    }

    /// Internal helper function for explicitly accessing the `bson_iter_t` as an unsafe pointer
    internal func withBSONIterPointer<Result>(_ body: (BSONIterPointer) throws -> Result) rethrows -> Result {
#if compiler(>=5.0)
        return try withUnsafePointer(to: self._iter) { iterPtr in
            try body(BSONIterPointer(iterPtr))
        }
#else
        return try withUnsafePointer(to: self._iter, body)
#endif
    }

    /// Internal helper function for explicitly accessing the `bson_iter_t` as an unsafe mutable pointer
    internal func withMutableBSONIterPointer<Result>(
      _ body: (MutableBSONIterPointer) throws -> Result
    ) rethrows -> Result {
#if compiler(>=5.0)
        return try withUnsafeMutablePointer(to: &self._iter) { iterPtr in
            try body(MutableBSONIterPointer(iterPtr))
        }
#else
        return try withUnsafeMutablePointer(to: &self._iter, body)
#endif
    }

    private static let bsonTypeMap: [BSONType: BSONValue.Type] = [
        .double: Double.self,
        .string: String.self,
        .document: Document.self,
        .array: [BSONValue].self,
        .binary: Binary.self,
        .objectId: ObjectId.self,
        .boolean: Bool.self,
        .dateTime: Date.self,
        .regularExpression: RegularExpression.self,
        .dbPointer: DBPointer.self,
        .javascript: CodeWithScope.self,
        .symbol: Symbol.self,
        .javascriptWithScope: CodeWithScope.self,
        .int32: Int.bsonType == .int32 ? Int.self : Int32.self,
        .timestamp: Timestamp.self,
        .int64: Int.bsonType == .int64 ? Int.self : Int64.self,
        .decimal128: Decimal128.self,
        .minKey: MinKey.self,
        .maxKey: MaxKey.self,
        .null: BSONNull.self,
        .undefined: BSONUndefined.self
    ]
}
