import Foundation

/// An empty protocol for encapsulating all errors that BSON package can throw.
public protocol BSONErrorProtocol: LocalizedError {}

/// Namespace containing all the error types introduced by this BSON library and their dependent types.
public enum BSONError {
    /// An error thrown when the user passes in invalid arguments to a BSON method.
    public struct InvalidArgumentError: BSONErrorProtocol {
        internal let message: String

        public var errorDescription: String? { self.message }
    }

    /// An error thrown when the BSON library encounters a internal error not caused by the user.
    /// This is usually indicative of a bug in the BSON library or system related failure.
    public struct InternalError: BSONErrorProtocol {
        internal let message: String

        public var errorDescription: String? { self.message }
    }

    /// An error thrown when the BSON library is incorrectly used.
    public struct LogicError: BSONErrorProtocol {
        internal let message: String

        public var errorDescription: String? { self.message }
    }

    /// An error thrown when a document exceeds the maximum BSON encoding size.
    public struct DocumentTooLargeError: BSONErrorProtocol {
        internal let message: String

        public var errorDescription: String? { self.message }

        internal init(value: BSONValue, forKey: String) {
            self.message =
                "Failed to set value for key \(forKey) to \(value) with" +
                " BSON type \(value.bsonType): document too large"
        }
    }
}

internal func wrongIterTypeError(_ iter: BSONDocumentIterator, expected type: BSONValue.Type) -> BSONErrorProtocol {
    BSONError.LogicError(
        message: "Tried to retreive a \(type) from an iterator whose next type " +
            "is \(iter.currentType) for key \(iter.currentKey)"
    )
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. BSONObjectID) is encoded not using BSONEncoder
internal func bsonEncodingUnsupportedError<T: BSONValue>(value: T, at codingPath: [CodingKey]) -> EncodingError {
    let description = "Encoding \(T.self) BSONValue type with a non-BSONEncoder is currently unsupported"

    return EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/// Error thrown when a BSONValue type introduced by the driver (e.g. BSONObjectID) is decoded not using BSONDecoder
internal func bsonDecodingUnsupportedError<T: BSONValue>(type _: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Initializing a \(T.self) BSONValue type with a non-BSONDecoder is currently unsupported"

    return DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/**
 * Error thrown when a `BSONValue` type introduced by the driver (e.g. BSONObjectID) is decoded directly via the
 * top-level `BSONDecoder`.
 */
internal func bsonDecodingDirectlyError<T: BSONValue>(type _: T.Type, at codingPath: [CodingKey]) -> DecodingError {
    let description = "Cannot initialize BSONValue type \(T.self) directly from BSONDecoder. It must be decoded as " +
        "a member of a struct or a class."

    return DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(codingPath: codingPath, debugDescription: description)
    )
}

/**
 * This function determines which error to throw when a driver-introduced BSON type is decoded via its init(decoder).
 * The types that use this function are all BSON primitives, so they should be decoded directly in `_BSONDecoder`. If
 * execution reaches their decoding initializer, it means something went wrong. This function determines an appropriate
 * error to throw for each possible case.
 *
 * Some example cases:
 *   - Decoding directly from the BSONDecoder top-level (e.g. BSONDecoder().decode(BSONObjectID.self, from: ...))
 *   - Encountering the wrong type of BSONValue (e.g. expected "_id" to be an `BSONObjectID`, got a `BSONDocument`
 *     instead)
 *   - Attempting to decode a driver-introduced BSONValue with a non-BSONDecoder
 */
internal func getDecodingError<T: BSONValue>(type _: T.Type, decoder: Decoder) -> DecodingError {
    if let bsonDecoder = decoder as? _BSONDecoder {
        // Cannot decode driver-introduced BSONValues directly
        if decoder.codingPath.isEmpty {
            return bsonDecodingDirectlyError(type: T.self, at: decoder.codingPath)
        }

        // Got the wrong BSONValue type
        return DecodingError._typeMismatch(
            at: decoder.codingPath,
            expectation: T.self,
            reality: bsonDecoder.storage.topContainer.bsonValue
        )
    }

    // Non-BSONDecoders are currently unsupported
    return bsonDecodingUnsupportedError(type: T.self, at: decoder.codingPath)
}
