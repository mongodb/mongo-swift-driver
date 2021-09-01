@testable import struct MongoSwift.ReadPreference
import MongoSwiftSync
import TestsCommon

/// Allows a type to specify a set of known keys and check whether any unknown top-level keys are found in a decoder.
internal protocol StrictDecodable: Decodable {
    associatedtype CodingKeysType: CodingKey, CaseIterable, RawRepresentable where CodingKeysType.RawValue == String

    /// Checks whether the top-level container in the decoder contains any keys that do not match up with cases in the
    /// associated CodingKeysType.
    static func checkKeys(using decoder: Decoder) throws
}

extension StrictDecodable {
    /// Default implementation of checkKeys.
    static func checkKeys(using decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawKeys = try container.decode(BSONDocument.self).keys
        let supportedKeys = Set(Self.CodingKeysType.allCases.map { $0.rawValue })
        for key in rawKeys {
            guard supportedKeys.contains(key) else {
                throw TestError(message: "Unsupported key \(key) found while decoding instance of \(Self.self)")
            }
        }
    }
}

extension MongoDatabaseOptions: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try container.decodeIfPresent(ReadConcern.self, forKey: .readConcern)
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try container.decodeIfPresent(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, readPreference: readPreference, writeConcern: writeConcern)
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case readConcern, readPreference, writeConcern
    }
}

extension MongoCollectionOptions: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try container.decodeIfPresent(ReadConcern.self, forKey: .readConcern)
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try container.decodeIfPresent(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, readPreference: readPreference, writeConcern: writeConcern)
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case readConcern, readPreference, writeConcern
    }
}

extension ClientSessionOptions: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let causalConsistency = try container.decodeIfPresent(Bool.self, forKey: .causalConsistency)
        let defaultTransactionOptions = try container.decodeIfPresent(
            TransactionOptions.self,
            forKey: .defaultTransactionOptions
        )
        self.init(causalConsistency: causalConsistency, defaultTransactionOptions: defaultTransactionOptions)
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case causalConsistency, defaultTransactionOptions
    }
}

extension TransactionOptions: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let maxCommitTimeMS = try container.decodeIfPresent(Int.self, forKey: .maxCommitTimeMS)
        let readConcern = try container.decodeIfPresent(ReadConcern.self, forKey: .readConcern)
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try container.decodeIfPresent(WriteConcern.self, forKey: .writeConcern)
        self.init(
            maxCommitTimeMS: maxCommitTimeMS,
            readConcern: readConcern,
            readPreference: readPreference,
            writeConcern: writeConcern
        )
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case maxCommitTimeMS, readConcern, readPreference, writeConcern
    }
}

extension ReadPreference.Mode: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var string = try container.decode(String.self)
        // spec tests capitalize first letter of mode, so need to account for that.
        string = string.prefix(1).lowercased() + string.dropFirst()
        guard let mode = Self(rawValue: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "can't parse ReadPreference mode from \(string)"
            )
        }
        self = mode
    }
}

extension ReadPreference: Decodable {
    private enum CodingKeys: String, CodingKey {
        case mode
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let mode = try container.decode(Mode.self, forKey: .mode)
            self.init(mode)
        } else { // sometimes the spec tests only specify the mode as a string
            let container = try decoder.singleValueContainer()
            let mode = try container.decode(ReadPreference.Mode.self)
            self.init(mode)
        }
    }
}

extension MongoClientOptions: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case retryReads, retryWrites, w, readConcernLevel, readPreference, heartbeatFrequencyMS, loadBalanced, appname
    }

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? ReadConcern.other(container.decode(String.self, forKey: .readConcernLevel))
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let retryReads = try container.decodeIfPresent(Bool.self, forKey: .retryReads)
        let retryWrites = try container.decodeIfPresent(Bool.self, forKey: .retryWrites)
        let writeConcern = try? WriteConcern(w: container.decode(WriteConcern.W.self, forKey: .w))
        let heartbeatFrequencyMS = try container.decodeIfPresent(Int.self, forKey: .heartbeatFrequencyMS)
        let loadBalanced = try container.decodeIfPresent(Bool.self, forKey: .loadBalanced)
        let appName = try container.decodeIfPresent(String.self, forKey: .appname)
        self.init(
            appName: appName,
            heartbeatFrequencyMS: heartbeatFrequencyMS,
            loadBalanced: loadBalanced,
            readConcern: readConcern,
            readPreference: readPreference,
            retryReads: retryReads,
            retryWrites: retryWrites,
            writeConcern: writeConcern
        )
    }
}
