import CLibMongoC
import Foundation
import NIO

internal typealias BSONPointer = UnsafePointer<bson_t>
internal typealias MutableBSONPointer = UnsafeMutablePointer<bson_t>

/**
 * Executes the given closure with a read-only `BSONPointer` to the provided `BSONDocument` if non-nil.
 * The pointer will only be valid within the body of the closure, and it MUST NOT be persisted outside of it.
 *
 * Use this function rather than optional chaining on `BSONDocument` to guarantee the provided closure is executed.
 */
internal func withOptionalBSONPointer<T>(
    to document: BSONDocument?,
    body: (BSONPointer?) throws -> T
) rethrows -> T {
    guard let doc = document else {
        return try body(nil)
    }
    return try doc.withBSONPointer(body)
}

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
     */
    internal init(copying bsonPtr: BSONPointer) {
        guard let ptr = bson_get_data(bsonPtr) else {
            fatalError("bson_t data is null")
        }
        let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(bsonPtr.pointee.len))
        do {
            try self.init(fromBSON: Data(bufferPtr))
        } catch {
            fatalError("Failed initializing BSONDocument from bson_t: \(error)")
        }
    }
}

extension Data {
    /// Gets access to the start of the data buffer in the form of an UnsafeMutablePointer<CChar>. Useful for calling C
    /// API methods that expect a location for a string. **You must only call this method on Data instances with
    /// count > 0 so that the base address will exist.**
    /// Based on https://mjtsai.com/blog/2019/03/27/swift-5-released/
    fileprivate mutating func withUnsafeMutableCStringPointer<T>(
        body: (UnsafeMutablePointer<CChar>) throws -> T
    ) rethrows -> T {
        try self.withUnsafeMutableBytes { (rawPtr: UnsafeMutableRawBufferPointer) in
            let bufferPtr = rawPtr.bindMemory(to: CChar.self)
            // baseAddress is non-nil as long as Data's count > 0.
            // swiftlint:disable:next force_unwrapping
            let bytesPtr = bufferPtr.baseAddress!
            return try body(bytesPtr)
        }
    }
}

extension bson_oid_t {
    /// This `bson_oid_t`'s data represented as a `String`.
    public var hex: String {
        var str = Data(count: 25)
        return str.withUnsafeMutableCStringPointer { strPtr in
            withUnsafePointer(to: self) { oidPtr in
                bson_oid_to_string(oidPtr, strPtr)
            }
            return String(cString: strPtr)
        }
    }
}

extension BSONObjectID {
    internal init(bsonOid: bson_oid_t) {
        let hex = bsonOid.hex
        do {
            try self.init(hex)
        } catch {
            fatalError("failed to initialize ObjectID from bson_oid_t hex \(hex): \(error)")
        }
    }
}
