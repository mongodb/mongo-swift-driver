import Foundation

/// An extension of `Document` to make it conform to the `Collection` protocol.
/// This gives guarantees on non-destructive iteration, and offers an indexed
/// ordering to the key value pairs in the document.
extension Document: Collection {
    /// Returns the start index of the Document.
    public var startIndex: Int {
        return 0
    }

    /// Returns the end index of the Document.
    public var endIndex: Int {
        return self.count
    }

    /// Returns the index after the given index for this Document.
    public func index(after i: Int) -> Int {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        _failEarlyRangeCheck(i, bounds: self.startIndex ... self.endIndex)
        return i + 1
    }

    /// Allows access to a `KeyValuePair` from the `Document`, given the position of the desired `KeyValuePair` held
    /// within. This method does not guarantee constant-time (O(1)) access.
    public subscript(position: Int) -> Document.KeyValuePair {
        // TODO: This method _should_ guarantee constant-time O(1) access, and it is possible to make it do so. This
        // criticism also applies to key-based subscripting via `String`.
        // See SWIFT-250.
        _failEarlyRangeCheck(position, bounds: self.startIndex ... self.endIndex)
        return self.makeIterator().keyValuePairs[position]
    }

    /// Allows access to a `KeyValuePair` from the `Document`, given a range of indices of the desired `KeyValuePair`'s
    /// held within. This method does not guarantee constant-time (O(1)) access.
    public subscript(bounds: Range<Int>) -> Document {
        let keyValues = self.keyValuePairs
        // TODO: SWIFT-252 should provide a more efficient implementation for this.
        return Document(Array(keyValues[bounds]))
    }
}
