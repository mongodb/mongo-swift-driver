import Foundation

/// An empty protocol for encapsulating all errors that BSON package can throw.
public protocol BSONErrorProtocol: LocalizedError {}

/// A protocol describing errors caused by improper usage of the BSON library by the user.
public protocol BSONUserError: BSONErrorProtocol {}

/// The possible errors that can occur unexpectedly BSON library-side.
public protocol BSONRuntimeError: BSONErrorProtocol {}

/// Namespace containing all the error types introduced by this BSON library and their dependent types.
public enum BSONError {
    /// An error thrown when the user passes in invalid arguments to a BSON method.
    public struct InvalidArgumentError: BSONUserError {
        internal let message: String

        public var errorDescription: String? { self.message }
    }

    /// An error thrown when the BSON library encounters a internal error not caused by the user.
    /// This is usually indicative of a bug in the BSON library or system related failure.
    public struct InternalError: BSONRuntimeError {
        internal let message: String

        public var errorDescription: String? { self.message }
    }

    /// An error thrown when the BSON library is incorrectly used.
    public struct LogicError: BSONUserError {
        internal let message: String

        public var errorDescription: String? { self.message }
    }
}

internal func bsonTooLargeError(value: BSONValue, forKey: String) -> BSONErrorProtocol {
    BSONError.InternalError(
        message:
        "Failed to set value for key \(forKey) to \(value) with BSON type \(value.bsonType): document too large"
    )
}

internal func wrongIterTypeError(_ iter: BSONDocumentIterator, expected type: BSONValue.Type) -> BSONErrorProtocol {
    BSONError.LogicError(
        message: "Tried to retreive a \(type) from an iterator whose next type " +
            "is \(iter.currentType) for key \(iter.currentKey)"
    )
}
