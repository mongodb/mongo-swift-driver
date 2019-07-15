import Foundation

/// A struct to represent the BSON Binary type.
public struct PureBSONBinary: PureBSONValue {
    /// The binary data.
    private let data: Data

    /// The binary subtype for this data.
    private let subtype: Subtype

    /// Subtypes for BSON Binary values.
    public enum Subtype: UInt8 {
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

    internal init(from data: Data) throws {
        guard data.count >= 5 else {
            throw RuntimeError.internalError(message: "binary data must be at least 5 bytes for length and subtype")
        }

        let length = try Int32(from: data[0...4])

        guard let sub = Subtype(rawValue: data[0]) else {
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
        data.append(contentsOf: [self.subtype.rawValue])
        data.append(Int32(self.data.count).toBSON())
        data.append(data)
        return data
    }
}
