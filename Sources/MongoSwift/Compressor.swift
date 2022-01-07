/// Specifies a library to use for network compression.
public struct Compressor: CustomStringConvertible, Equatable {
    internal enum _Compressor: Equatable {
        case zlib(level: Int32?)
    }

    /// The compressor to use.
    internal let _compressor: _Compressor

    private init(_ compressor: _Compressor) {
        self._compressor = compressor
    }

    /// Use zlib for data compression.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/glossary/#term-zlib
    public static let zlib = Compressor(.zlib(level: nil))

    /// Use zlib for data compression, with the specified compression level.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.zlibCompressionLevel
    public static func zlib(level: Int) throws -> Compressor {
        guard (-1...9).contains(level) else {
            throw MongoError.InvalidArgumentError(
                message: "Invalid zlib compression level \(level): must be between -1 and 9"
            )
        }
        return Compressor(.zlib(level: Int32(level)))
    }

    public var description: String {
        switch self._compressor {
        case let .zlib(level):
            guard let level = level else {
                return "zlib"
            }
            return "zlib(level:\(level))"
        }
    }
}
