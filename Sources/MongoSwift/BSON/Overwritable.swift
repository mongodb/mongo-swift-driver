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
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_bool(iterPtr, self) }
    }
}

extension Int: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        switch self.typedValue {
        case let int32 as Int32:
            return int32.writeToCurrentPosition(of: iter)
        case let int64 as Int64:
            return int64.writeToCurrentPosition(of: iter)
        default:
            throw RuntimeError.internalError(message: "`Int` value \(self) could not be encoded as `Int32` or `Int64`")
        }
    }
}

extension Int32: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_int32(iterPtr, self) }
    }
}

extension Int64: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_int64(iterPtr, self) }
    }
}

extension Double: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_double(iterPtr, self) }
    }
}

extension Decimal128: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        withUnsafePointer(to: self.decimal128) { ptr in
            // bson_iter_overwrite_decimal128 takes in a (non-const) *decimal_128_t, so we need to pass in a mutable
            // pointer. no mutation of self.decimal128 should occur, however. (CDRIVER-3069)
            iter.withMutableBSONIterPointer { iterPtr in
                bson_iter_overwrite_decimal128(iterPtr, UnsafeMutablePointer<bson_decimal128_t>(mutating: ptr))
            }
        }
    }
}

extension ObjectId: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) throws {
        withUnsafePointer(to: self.oid) { oidPtr in
            iter.withMutableBSONIterPointer { iterPtr in bson_iter_overwrite_oid(iterPtr, oidPtr) }
        }
    }
}

extension Timestamp: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in
            bson_iter_overwrite_timestamp(iterPtr, self.timestamp, self.increment)
        }
    }
}

extension Date: Overwritable {
    internal func writeToCurrentPosition(of iter: DocumentIterator) {
        iter.withMutableBSONIterPointer { iterPtr in
            bson_iter_overwrite_date_time(iterPtr, self.msSinceEpoch)
        }
    }
}
