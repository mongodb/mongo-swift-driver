import Foundation

/// An extension of `Document` to make it conform to the `Collection` protocol.
/// This gives guarantees on non-destructive iteration, and offers an indexed
/// ordering to the key-value pairs in the document.
extension Document: Collection {
    /// Returns the start index of the Document.
    public var startIndex: Index {
        return 0
    }

    /// Returns the end index of the Document.
    public var endIndex: Index {
        return self.count
    }

    private func failIndexCheck(_ i: Index) {
        let invalidIndexMsg = "Index \(i) is invalid"
        guard !self.isEmpty && self.startIndex ... self.endIndex - 1 ~= i else {
            fatalError(invalidIndexMsg)
        }
    }

    /// Returns the index after the given index for this Document.
    public func index(after i: Index) -> Index {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        failIndexCheck(i)
        return i + 1
    }

    /// Allows access to a `KeyValuePair` from the `Document`, given the position of the desired `KeyValuePair` held
    /// within. This method does not guarantee constant-time (O(1)) access.
    public subscript(position: Index) -> KeyValuePair {
        // TODO: This method _should_ guarantee constant-time O(1) access, and it is possible to make it do so. This
        // criticism also applies to key-based subscripting via `String`.
        // See SWIFT-250.
        failIndexCheck(position)

        let subsequence = DocumentIterator.subsequence(of: self, startIndex: position, endIndex: position + 1)

        // swiftlint:disable:next force_unwrapping - failIndexCheck precondition ensures non-nil result.
        return subsequence.makeIterator().next()!
    }

    /// Allows access to a `KeyValuePair` from the `Document`, given a range of indices of the desired `KeyValuePair`'s
    /// held within. This method does not guarantee constant-time (O(1)) access.
    public subscript(bounds: Range<Index>) -> Document {
        // TODO: SWIFT-252 should provide a more efficient implementation for this.
        return DocumentIterator.subsequence(of: self, startIndex: bounds.lowerBound, endIndex: bounds.upperBound)
    }
}
