//
//  Document+Collection.swift
//  MongoSwift
//
//  Created by may on 11/8/18.
//

import Foundation

extension Document: Collection {
    /// Returns the start index of the Document.
    public var startIndex: Int {
        precondition(self.count > 0)
        return 0
    }

    /// Returns the end index of the Document.
    public var endIndex: Int {
        precondition(self.count > 0)
        return self.countFast
    }

    private func validIndex(_ i: Int) -> Bool {
        return self.startIndex ... self.endIndex - 1 ~= i
    }

    /// Returns the index after the given index for this Document.
    public func index(after i: Int) -> Int {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        precondition(validIndex(i))
        return i + 1
    }

    /// Allows access to a `KeyValuePair` from the `Document`, given the position of the desired `KeyValuePair` held
    /// within. This method does not guarantee constant-time (O(1)) access.
    public subscript(position: Int) -> Document.KeyValuePair {
        // TODO: This method _should_ guarantee constant-time O(1) access, and it is possible to make it do so. This
        // criticism also applies to key-based subscripting via `String`.
        // See SWIFT-250.
        precondition(validIndex(position))
        return self.makeIterator().keyValuePairs[position]
    }
}
