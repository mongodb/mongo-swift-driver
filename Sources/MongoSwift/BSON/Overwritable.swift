import libbson

/// A protocol indicating that a type can be overwritten in-place on a `bson_t`.
internal protocol Overwritable: BsonValue {
    /// Overwrites the value at the current position of the iterator with self.
    func writeToCurrentPosition(of iter: DocumentIterator) throws
}

extension Bool: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_bool(&iter.iter, self) }
}

extension Int: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) throws {
        if let int32 = self.int32Value {
            return int32.writeToCurrentPosition(of: iter)
        } else if let int64 = self.int64Value {
            return int64.writeToCurrentPosition(of: iter)
        }

        throw MongoError.bsonEncodeError(message: "`Int` value \(self) could not be encoded as `Int32` or `Int64`")
    }
}

extension Int32: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int32(&iter.iter, self) }
}

extension Int64: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int64(&iter.iter, self) }
}

extension Double: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_double(&iter.iter, self) }
}

extension Decimal128: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) throws {
        var encoded = try Decimal128.encode(self.data)
        bson_iter_overwrite_decimal128(&iter.iter, &encoded)
    }
}
