import Foundation
import mongoc

/// An extension of `Document` to make it conform to the `Sequence` protocol.
/// This allows you to iterate through the (key, value) pairs, for example:
/// ```
/// let doc: Document = ["a": 1, "b": 2]
/// for (key, value) in doc {
///     ...
/// }
/// ```
extension Document: Sequence {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSONValue)

    // Since a `Document` is a recursive structure, we want to enforce the use of it as a subsequence of itself.
    // instead of something like `Slice<Document>`.
    /// The type that is returned from methods such as `dropFirst()` and `split()`.
    public typealias SubSequence = Document

    /// Returns a `Bool` indicating whether the document is empty.
    public var isEmpty: Bool { return !self.makeIterator().advance() }

    /// Returns a `DocumentIterator` over the values in this `Document`.
    public func makeIterator() -> DocumentIterator {
        guard let iter = DocumentIterator(forDocument: self) else {
            fatalError("Failed to initialize an iterator over document \(self)")
        }
        return iter
    }

    /**
     * Returns a new document containing the keys of this document with the values transformed by
     * the given closure.
     *
     * - Parameters:
     *   - transform: A closure that transforms a `BSONValue`. `transform` accepts each value of the
     *                document as its parameter and returns a transformed `BSONValue` of the same or
     *                of a different type.
     *
     * - Returns: A document containing the keys and transformed values of this document.
     *
     * - Throws: An error if `transform` throws an error.
     */
    public func mapValues(_ transform: (BSONValue) throws -> BSONValue) rethrows -> Document {
        var output = Document()
        for (k, v) in self {
            output[k] = try transform(v)
        }
        return output
    }

    public func dropFirst(_ n: Int) -> Document {
        switch n {
        case ..<0:
            fatalError("Can't drop a negative number of elements from a document")
        case 0:
            return self
        default:
            // get all the key-value pairs from nth index on. subsequence will handle the case where n >= length of doc
            // by creating an iter and calling advance until the end is reached. this is exactly what calling self.count
            // would do in that situation via bson_count_keys, so no point in special casing self.count <= n here.
            return DocumentIterator.subsequence(of: self, startIndex: n)
        }
    }

    public func dropLast(_ n: Int) -> Document {
        switch n {
        case ..<0:
            fatalError("Can't drop a negative number of elements from a `Document`")
        case 0:
            return self
        default:
            // the subsequence we want is [0, length - n)
            let end = self.count - n
            // if we are dropping >= the length, just short circuit and return empty doc
            return end <= 0 ? [:] : DocumentIterator.subsequence(of: self, endIndex: end)
        }
    }

    public func drop(while predicate: (KeyValuePair) throws -> Bool) rethrows -> Document {
        // tracks whether we are still in a "dropping" state. once we encounter
        // an element that doesn't satisfy the predicate, we stop dropping.
        var drop = true
        return try self.filter { elt in
            if drop {
                // still in "drop" mode and it matches predicate
                if try predicate(elt) {
                    return false
                }
                // else we've encountered our first non-matching element
                drop = false
                return true
            }
            // out of "drop" mode, so we keep everything
            return true
        }
    }

    public func prefix(_ maxLength: Int) -> Document {
        switch maxLength {
        case ..<0:
            fatalError("Can't retrieve a negative length prefix of a `Document`")
        case 0:
            return [:]
        default:
            // short circuit if there are fewer elements in the doc than requested
            return self.count <= maxLength ? self : DocumentIterator.subsequence(of: self, endIndex: maxLength)
        }
    }

    public func prefix(while predicate: (KeyValuePair) throws -> Bool) rethrows -> Document {
        var output = Document()
        for elt in self {
            if try !predicate(elt) { break }
            output[elt.key] = elt.value
        }
        return output
    }

    public func suffix(_ maxLength: Int) -> Document {
        switch maxLength {
        case ..<0:
            fatalError("Can't retrieve a negative length suffix of a `Document`")
        case 0:
            return [:]
        default:
            let start = self.count - maxLength
            // short circuit if there are fewer elements in the doc than requested
            return start <= 0 ? self : DocumentIterator.subsequence(of: self, startIndex: start)
        }
    }

    public func split(maxSplits: Int = Int.max,
                      omittingEmptySubsequences: Bool = true,
                      whereSeparator isSeparator: (KeyValuePair) throws -> Bool) rethrows -> [Document] {
        // rather than implementing the complex logic necessary for split, convert to an array and call split on that
        let asArr = Array(self)
        // convert to a [[KeyValuePair]]
        let splitArrs = try asArr.split(maxSplits: maxSplits,
                                        omittingEmptySubsequences: omittingEmptySubsequences,
                                        whereSeparator: isSeparator)

        // convert each nested [KeyValuePair] back to a Document
        var output = [Document]()
        splitArrs.forEach { array in
            var doc = Document()
            array.forEach { doc[$0.key] = $0.value }
            output.append(doc)
        }

        return output
    }
}

extension Document {
    // this is an alternative to the built-in `Document.filter` that returns an `[KeyValuePair]`. 
    // this variant is called by default, but the other is still accessible by explicitly stating
    // return type: `let newDocPairs: [Document.KeyValuePair] = newDoc.filter { ... }`
    /**
     * Returns a new document containing the key-value pairs of the dictionary that satisfy the given predicate.
     *
     * - Parameters:
     *   - isIncluded: A closure that takes a key-value pair as its argument and returns a `Bool` indicating whether
     *                 the pair should be included in the returned document.
     *
     * - Returns: A document of the key-value pairs that `isIncluded` allows.
     *
     * - Throws: An error if `isIncluded` throws an error.
     */
    public func filter(_ isIncluded: (KeyValuePair) throws -> Bool) rethrows -> Document {
        var output = Document()
        for elt in self where try isIncluded(elt) {
            output[elt.key] = elt.value
        }
        return output
    }
}

/// An iterator over the values in a `Document`.
public class DocumentIterator: IteratorProtocol {
    /// the libbson iterator. it must be a `var` because we use it as
    /// an inout argument
    internal var iter: bson_iter_t
    /// a reference to the storage for the document we're iterating
    internal let storage: DocumentStorage

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if the key is not
    /// found, or if an iterator cannot be created over `doc` due to an error from e.g. corrupt data.
    internal init?(forDocument doc: Document) {
        self.iter = bson_iter_t()
        self.storage = doc.storage
        guard bson_iter_init(&self.iter, doc.data) else {
            return nil
        }
    }

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if an iterator cannot
    /// be created over `doc` due to an error from e.g. corrupt data, or if the key is not found.
    internal init?(forDocument doc: Document, advancedTo key: String) {
        self.iter = bson_iter_t()
        self.storage = doc.storage
        guard bson_iter_init_find(&iter, doc.data, key.cString(using: .utf8)) else {
            return nil
        }
    }

    /// Advances the iterator forward one value. Returns false if there is an error moving forward
    /// or if at the end of the document. Returns true otherwise.
    internal func advance() -> Bool {
        return bson_iter_next(&self.iter)
    }

    /// Moves the iterator to the specified key. Returns false if the key does not exist. Returns true otherwise.
    internal func move(to key: String) -> Bool {
        return bson_iter_find(&self.iter, key.cString(using: .utf8))
    }

    /// Returns the current key. Assumes the iterator is in a valid position.
    internal var currentKey: String {
        return String(cString: bson_iter_key(&self.iter))
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
        return BSONType(rawValue: bson_iter_type(&self.iter).rawValue) ?? .invalid
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
        guard let curVal = try DocumentIterator.bsonTypeMap[currentType]?.from(iterator: self) else {
            throw RuntimeError.internalError(message: "Unknown BSONType for iterator's current value.")
        }

        return curVal
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
        .int32: Int.self,
        .timestamp: Timestamp.self,
        .int64: Int64.self,
        .decimal128: Decimal128.self,
        .minKey: MinKey.self,
        .maxKey: MaxKey.self,
        .null: BSONNull.self,
        .undefined: BSONUndefined.self
    ]
}
