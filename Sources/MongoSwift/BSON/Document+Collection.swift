//
//  Document+Collection.swift
//  MongoSwift
//
//  Created by may on 11/8/18.
//

import Foundation

extension Document: Collection {
    public subscript(position: Int) -> Document.KeyValuePair {
        return (self.keys[position], self.values[position])
    }

    public var startIndex: Int {
        precondition(self.count > 0)
        return self.keys.startIndex
    }

    public var endIndex: Int {
        precondition(self.count > 0)
        return self.keys.endIndex
    }

    public func index(after i: Int) -> Int {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        precondition(self.startIndex ... self.endIndex - 1 ~= i)
        return self.keys.index(after: i)
    }
}
