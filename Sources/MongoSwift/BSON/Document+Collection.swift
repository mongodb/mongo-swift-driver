//
//  Document+Collection.swift
//  MongoSwift
//
//  Created by may on 11/8/18.
//

import Foundation

extension Document: Collection {
    public var startIndex: Int {
        precondition(self.count > 0)
        return 0
    }

    public var endIndex: Int {
        precondition(self.count > 0)
        return self.count
    }

    public func index(after i: Int) -> Int {
        // Index must be a valid one, meaning it must exist somewhere in self.keys.
        precondition(self.startIndex ... self.endIndex - 1 ~= i)
        return i + 1
    }

    public subscript(position: Int) -> Document.KeyValuePair {
        return (self.keys[position], self.values[position])
    }
}
