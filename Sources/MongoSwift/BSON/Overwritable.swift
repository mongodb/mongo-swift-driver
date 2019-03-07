import bson
import Foundation

/// A protocol indicating that a type can be overwritten in-place on a `bson_t`.
internal protocol Overwritable: BSONValue {
    /**
     * Overwrites the value at the current position of the iterator with self.
     *
     * - Throws:
     *   - `RuntimeError.internalError` if the `BSONValue` is an `Int` and cannot be written to BSON.
     *   - `UserError.logicError` if the `BSONValue` is a `Decimal128` or `ObjectId` and is improperly formatted.
     */
    func writeToCurrentPosition(of iter: DocumentIterator) throws
}

extension Bool: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_bool(&iter.iter, self) }
}

extension Int: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        if let int32 = self.int32Value {
            return int32.writeToCurrentPosition(of: iter)
        } else if let int64 = self.int64Value {
            return int64.writeToCurrentPosition(of: iter)
        }

        throw RuntimeError.internalError(message: "`Int` value \(self) could not be encoded as `Int32` or `Int64`")
    }
}

extension Int32: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int32(&iter.iter, self) }
}

extension Int64: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int64(&iter.iter, self) }
}

extension Double: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_double(&iter.iter, self) }
}

extension Decimal128: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        // TODO: avoid this copy via withUnsafePointer use once swift 4.1 support is dropped (SWIFT-284)
        var copy = self.decimal128
        bson_iter_overwrite_decimal128(&iter.iter, &copy)
    }
}

extension ObjectId: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        var encoded = try ObjectId.toLibBSONType(self.oid)
        bson_iter_overwrite_oid(&iter.iter, &encoded)
    }
}

extension Timestamp: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        bson_iter_overwrite_timestamp(&iter.iter, self.timestamp, self.increment)
    }
}

extension Date: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        bson_iter_overwrite_date_time(&iter.iter, self.msSinceEpoch)
    }
}
