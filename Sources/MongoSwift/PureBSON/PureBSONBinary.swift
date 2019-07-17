import Foundation

/// A struct to represent the BSON Binary type.
public struct PureBSONBinary {
    /// The binary data.
    public let data: Data

    /// The binary subtype for this data.
    public let subtype: Subtype

    /// Subtypes for BSON Binary values.
    public enum Subtype: UInt8, Codable {
        /// Generic binary subtype
        case generic,
             /// A function
             function,
             /// Binary (old)
             binaryDeprecated,
             /// UUID (old)
             uuidDeprecated,
             /// UUID (RFC 4122)
             uuid,
             /// MD5
             md5,
             /// User defined
             userDefined = 0x80
    }

    /// Initializes a `Binary` instance from a `UUID`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if a `Binary` cannot be constructed from this UUID.
    public init(from uuid: UUID) throws {
        let uuidt = uuid.uuid

        let uuidData = Data(bytes: [
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])

        try self.init(data: uuidData, subtype: Subtype.uuid)
    }

    /// Initializes a `Binary` instance from a `Data` object and a `Subtype`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: Subtype) throws {
        if [Subtype.uuid, Subtype.uuidDeprecated].contains(subtype) && data.count != 16 {
            throw UserError.invalidArgumentError(
                    message: "Binary data with UUID subtype must be 16 bytes, but data has \(data.count) bytes")
        }
        self.subtype = subtype
        self.data = data
    }
}

extension PureBSONBinary: Codable {}

extension PureBSONBinary: Equatable {}

extension PureBSONBinary: Hashable {}

extension PureBSONBinary: PureBSONValue {
    internal static var bsonType: BSONType { return .binary }

    internal var bson: BSON { return .binary(self) }

    internal init(from data: Data) throws {
        guard data.count >= 5 else {
            throw RuntimeError.internalError(message: "binary data must be at least 5 bytes for length and subtype")
        }

        let length = try Int32(from: data[0...4])

        guard let sub = Subtype(rawValue: data[4]) else {
            throw RuntimeError.internalError(message: "invalid subtype: \(data[0])")
        }

        guard length + 1 + 4 == data.count else {
            throw RuntimeError.internalError(message: "buffer not sized correctly")
        }

        self.subtype = sub
        self.data = data.subdata(in: 5..<(5 + Int(length)))
    }

    internal func toBSON() -> Data {
        var data = Data()
        data.append(Int32(self.data.count).toBSON())
        data.append(contentsOf: [self.subtype.rawValue])
        data.append(self.data)
        return data
    }
}

/// Extension to allow a `UUID` to be initialized from a `Binary` `BSONValue`.
extension UUID {
    /// Initializes a `UUID` instance from a `Binary` `BSONValue`.
    /// - Throws:
    ///   - `UserError.invalidArgumentError` if a non-UUID subtype is set on the `Binary`.
    public init(from binary: PureBSONBinary) throws {
        guard [
                  Binary.Subtype.uuid.rawValue,
                  Binary.Subtype.uuidDeprecated.rawValue
              ].contains(binary.subtype.rawValue) else {
            throw UserError.invalidArgumentError(message: "Expected a UUID binary type " +
                    "(\(Binary.Subtype.uuid)), got \(binary.subtype) instead.")
        }

        let data = binary.data
        let uuid: uuid_t = (
                data[0], data[1], data[2], data[3],
                data[4], data[5], data[6], data[7],
                data[8], data[9], data[10], data[11],
                data[12], data[13], data[14], data[15]
        )

        self.init(uuid: uuid)
    }
}
