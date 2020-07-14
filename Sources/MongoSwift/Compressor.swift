/// Specifies a library to use for network compression.
public struct Compressor {
    /// Use zlib for data compression.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/glossary/#term-zlib
    public static let zlib = Compressor("zlib")

    /// Use zlib for data compression, with the specified compression level.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/connection-string/#urioption.zlibCompressionLevel
    public static func zlib(level: Int) throws -> Compressor {
        try Compressor("zlib", level: level)
    }

    /// Compressor name.
    internal let name: String

    internal let zLibLevel: Int32?

    private init(_ compressor: String) {
        self.name = compressor
        self.zLibLevel = nil
    }

    private init(_ compressor: String, level: Int) throws {
        guard (-1...9).contains(level) else {
            throw MongoError.InvalidArgumentError(
                message: "Invalid zlib compression level \(level): must be between -1 and 9"
            )
        }
        self.name = compressor
        self.zLibLevel = Int32(level)
    }
}
