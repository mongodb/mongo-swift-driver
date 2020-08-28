import CLibMongoC
import Foundation
import struct SwiftBSON.BSONDocument

extension SwiftBSON.BSONDocument {
    /// Executes the given closure with a read-only, stack-allocated pointer to a bson_t.
    /// The pointer is only valid within the body of the closure and MUST NOT be persisted outside of it.
    internal func withBSONPointer<T>(_ f: (BSONPointer) throws -> T) rethrows -> T {
        var bson = bson_t()
        return try self.buffer.withUnsafeReadableBytes { bufferPtr in
            guard let baseAddrPtr = bufferPtr.baseAddress else {
                fatalError("BSONDocument buffer pointer is null")
            }
            guard bson_init_static(&bson, baseAddrPtr.assumingMemoryBound(to: UInt8.self), bufferPtr.count) else {
                fatalError("failed to initialize read-only bson_t from BSONDocument")
            }
            return try f(&bson)
        }
    }

    /**
     * Copies the data from the given `BSONPointer` into a new `BSONDocument`.
     *
     *  Throws an `MongoError.InternalError` if the bson_t isn't proper BSON.
     */
    internal init(copying bsonPtr: BSONPointer) throws {
        guard let ptr = bson_get_data(bsonPtr) else {
            fatalError("bson_t data is null")
        }
        let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(bsonPtr.pointee.len))
        do {
            try self.init(fromBSON: Data(bufferPtr))
        } catch {
            throw MongoError.InternalError(message: "failed initializing BSONDocument from bson_t: \(error)")
        }
    }
}
