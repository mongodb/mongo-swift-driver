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
     * Returns a new document containing the keys of this document with the values transformed by the given closure.
     *
     * - Parameters:
     *   - transform: A closure that transforms a `BSONValue`. `transform` accepts each value of the document as its
     *                parameter and returns a transformed `BSONValue` of the same or of a different type.
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

    /**
     * Returns a document containing all but the given number of initial key-value pairs.
     *
     * - Parameters:
     *   - k: The number of key-value pairs to drop from the beginning of the document. k must be > 0.
     *
     * - Returns: A document starting after the specified number of key-value pairs.
     */
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

    /**
     * Returns a document containing all but the given number of final key-value pairs.
     *
     * - Parameters:
     *   - k: The number of key-value pairs to drop from the end of the document. Must be greater than or equal to zero.
     *
     * - Returns: A document leaving off the specified number of final key-value pairs.
     */
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

    /**
     * Returns a document by skipping the initial, consecutive key-value pairs that satisfy the given predicate.
     *
     * - Parameters:
     *   - predicate: A closure that takes a key-value pair as its argument and returns a boolean indicating whether
     *                the key-value pair should be included in the result.
     *
     * - Returns: A document starting after the initial, consecutive key-value pairs that satisfy `predicate`.
     *
     * - Throws: An error if `predicate` throws an error.
     */
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

    /**
     * Returns a document, up to the specified maximum length, containing the initial key-value pairs of the document.
     *
     * - Parameters:
     *   - maxLength: The maximum length for the returned document. Must be greater than or equal to zero.
     *
     * - Returns: A document starting at the beginning of this document with at most `maxLength` key-value pairs.
     */
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

    /**
     * Returns a document containing the initial, consecutive key-value pairs that satisfy the given predicate.
     *
     * - Parameters:
     *   - predicate: A closure that takes a key-value pair as its argument and returns a boolean indicating whether
     *                the key-value pair should be included in the result.
     *
     * - Returns: A document containing the initial, consecutive key-value pairs that satisfy `predicate`.
     *
     * - Throws: An error if `predicate` throws an error.
     */
    public func prefix(while predicate: (KeyValuePair) throws -> Bool) rethrows -> Document {
        var output = Document()
        for elt in self {
            if try !predicate(elt) { break }
            output[elt.key] = elt.value
        }
        return output
    }

    /**
     * Returns a document, up to the specified maximum length, containing the final key-value pairs of the document.
     *
     * - Parameters:
     *   - maxLength: The maximum length for the returned document. Must be greater than or equal to zero.
     *
     * - Returns: A document ending at the end of this document with at most `maxLength` key-value pairs.
     */
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

    /**
     * Returns the longest possible subsequences of the document, in order, that don’t contain key-value pairs
     * satisfying the given predicate. Key-value pairs that are used to split the document are not returned as part of
     * any subsequence.
     *
     * - Parameters:
     *   - maxSplits: The maximum number of times to split the document, or one less than the number of subsequences to
     *                return. If `maxSplits` + 1 subsequences are returned, the last one is a suffix of the original
     *                document containing the remaining key-value pairs. `maxSplits` must be greater than or equal to
     *                zero. The default value is `Int.max`.
     *   - omittingEmptySubsequences: If false, an empty document is returned in the result for each pair of
     *                                consecutive key-value pairs satisfying the `isSeparator` predicate and for each
     *                                key-value pair at the start or end of the document satisfying the `isSeparator`
     *                                predicate. If true, only nonempty documents are returned. The default value is
     *                                true.
     *   - isSeparator: A closure that returns true if its argument should be used to split the document and otherwise
     *                  returns false.
     *
     * - Returns: An array of documents, split from this document's key-value pairs.
     */
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
     * Returns a new document containing the elements of the document that satisfy the given predicate.
     *
     * - Parameters:
     *   - isIncluded: A closure that takes a key-value pair as its argument and returns a `Bool` indicating whether
     *                 the pair should be included in the returned document.
     *
     * - Returns: A document containing the key-value pairs that `isIncluded` allows.
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
