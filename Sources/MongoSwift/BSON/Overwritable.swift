import CLibMongoC
import Foundation

/// A protocol indicating that a type can be overwritten in-place on a `bson_t`.
internal protocol Overwritable: BSONValue {
    /**
     * Overwrites the value at the current position of the iterator with self.
     *
     * - Throws:
     *   - `InternalError` if the `BSONValue` is an `Int` and cannot be written to BSON.
     *   - `LogicError` if the `BSONValue` is a `BSONDecimal128` or `BSONObjectID` and is improperly formatted.
     */
    func writeToCurrentPosition(of iter: BSONDocumentIterator) throws
}

extension Bool: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_bool(iterPtr, self) }
    }
}

extension Int32: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_int32(iterPtr, self) }
    }
}

extension Int64: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_int64(iterPtr, self) }
    }
}

extension Double: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_double(iterPtr, self) }
    }
}

extension BSONDecimal128: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) throws {
        withUnsafePointer(to: self.decimal128) { decPtr in
            iter.withMutableBSONIterPointer { iterPtr in
                bson_iter_overwrite_decimal128(iterPtr, decPtr)
            }
        }
    }
}

extension BSONObjectID: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) throws {
        withUnsafePointer(to: self.oid) { oidPtr in
            iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_oid(iterPtr, oidPtr) }
        }
    }
}

extension BSONTimestamp: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in
            bson_iter_overwrite_timestamp(iterPtr, self.timestamp, self.increment)
        }
    }
}

extension Date: Overwritable {
    internal func writeToCurrentPosition(of iter: BSONDocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in
            bson_iter_overwrite_date_time(iterPtr, self.msSinceEpoch)
        }
    }
}
