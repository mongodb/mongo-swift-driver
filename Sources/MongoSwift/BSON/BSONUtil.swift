import Foundation

/*
 * BSONUtil contains helpers to wrap the underlying BSON library to assist in providing a consistent API
 */

/// We don't want driver users to handle any BSONErrors
/// this will convert BSONError.* thrown from `fn` to MongoError.* and rethrow
internal func convertingBSONErrors<T>(_ body: () throws -> T) rethrows -> T {
    do {
        return try body()
    } catch let error as BSONError.InvalidArgumentError {
        throw MongoError.InvalidArgumentError(message: error.errorDescription ?? "")
    } catch let error as BSONError.InternalError {
        throw MongoError.InternalError(message: error.errorDescription ?? "")
    } catch let error as BSONError.LogicError {
        throw MongoError.LogicError(message: error.errorDescription ?? "")
    } catch let error as BSONError.DocumentTooLargeError {
        throw MongoError.InternalError(message: error.errorDescription ?? "")
    } catch let error as BSONErrorProtocol {
        throw MongoError.InternalError(message: error.errorDescription ?? "Uknown BSON Error")
    }
}

extension BSONDecoder {
    /// Initializes `self`.
    public convenience init(options: CodingStrategyProvider?) {
        self.init()
        self.configureWithOptions(options: options)
    }

    /// Initializes `self` by using the options of another `BSONDecoder` and the provided options, with preference
    /// going to the provided options in the case of conflicts.
    internal convenience init(copies other: BSONDecoder, options: CodingStrategyProvider?) {
        self.init()
        self.userInfo = other.userInfo
        self.dateDecodingStrategy = other.dateDecodingStrategy
        self.uuidDecodingStrategy = other.uuidDecodingStrategy
        self.dataDecodingStrategy = other.dataDecodingStrategy
        self.configureWithOptions(options: options)
    }

    internal func configureWithOptions(options: CodingStrategyProvider?) {
        self.dateDecodingStrategy = options?.dateCodingStrategy?.rawValue.decoding ?? self.dateDecodingStrategy
        self.uuidDecodingStrategy = options?.uuidCodingStrategy?.rawValue.decoding ?? self.uuidDecodingStrategy
        self.dataDecodingStrategy = options?.dataCodingStrategy?.rawValue.decoding ?? self.dataDecodingStrategy
    }
}

extension BSONEncoder {
    /// Initializes `self`.
    public convenience init(options: CodingStrategyProvider?) {
        self.init()
        self.configureWithOptions(options: options)
    }

    /// Initializes `self` by using the options of another `BSONEncoder` and the provided options, with preference
    /// going to the provided options in the case of conflicts.
    internal convenience init(copies other: BSONEncoder, options: CodingStrategyProvider?) {
        self.init()
        self.userInfo = other.userInfo
        self.dateEncodingStrategy = other.dateEncodingStrategy
        self.uuidEncodingStrategy = other.uuidEncodingStrategy
        self.dataEncodingStrategy = other.dataEncodingStrategy

        self.configureWithOptions(options: options)
    }

    internal func configureWithOptions(options: CodingStrategyProvider?) {
        self.dateEncodingStrategy = options?.dateCodingStrategy?.rawValue.encoding ?? self.dateEncodingStrategy
        self.uuidEncodingStrategy = options?.uuidCodingStrategy?.rawValue.encoding ?? self.uuidEncodingStrategy
        self.dataEncodingStrategy = options?.dataCodingStrategy?.rawValue.encoding ?? self.dataEncodingStrategy
    }
}

extension Date {
    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    internal init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }
}

extension BSONTimestamp {
    /// Initializes a new  `BSONTimestamp` with the provided `timestamp` and `increment` values. Assumes
    /// the values can successfully be converted to `UInt32`s without loss of precision.
    internal init(timestamp: Int, inc: Int) {
        self.init(timestamp: UInt32(timestamp), inc: UInt32(inc))
    }
}

extension BSONDocument {
    /**
     * Initializes a `BSONDocument` using an array where the values are optional
     * `BSON`s. Values are stored under a string of their index in the
     * array.
     *
     * - Parameters:
     *   - elements: a `[BSON]`
     *
     * - Returns: a new `BSONDocument`
     */
    internal init(_ values: [BSON]) {
        var doc = BSONDocument()
        for (i, value) in values.enumerated() {
            doc["\(i)"] = value
        }
        self = doc
    }
}
