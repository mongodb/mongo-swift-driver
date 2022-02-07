import Foundation
@testable import MongoSwift

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
        let snapshot = try container.decodeIfPresent(Bool.self, forKey: .snapshot)
        let defaultTransactionOptions = try container.decodeIfPresent(
            TransactionOptions.self,
            forKey: .defaultTransactionOptions
        )
        self.init(
            causalConsistency: causalConsistency,
            defaultTransactionOptions: defaultTransactionOptions,
            snapshot: snapshot
        )
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case causalConsistency, defaultTransactionOptions, snapshot
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

extension ReadPreference: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            try Self.checkKeys(using: decoder)
            // Some tests specify a read preference with no fields to indicate the default read preference (i.e.
            // primary). Because this is not representable in the Swift driver due to the mode field not being
            // optional, this sets the mode to be primary explicitly if one is not present.
            let mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? Mode.primary
            self.init(mode)
            // The init method that takes in these fields also performs validation, so these fields are set manually to
            // allow decoding to succeed and ensure that validation occurs during server selection.
            self.tagSets = try container.decodeIfPresent([BSONDocument].self, forKey: .tagSets)
            self.maxStalenessSeconds = try container.decodeIfPresent(Int.self, forKey: .maxStalenessSeconds)
        } else { // sometimes the spec tests only specify the mode as a string
            let container = try decoder.singleValueContainer()
            let mode = try container.decode(ReadPreference.Mode.self)
            self.init(mode)
        }
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case mode, tagSets = "tag_sets", maxStalenessSeconds
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

extension TopologyDescription: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(TopologyDescription.TopologyType.self, forKey: .type)
        let servers = try values.decode([ServerDescription].self, forKey: .servers)

        self.init(type: type, servers: servers)
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case type, servers
    }
}

extension ServerDescription: StrictDecodable {
    internal typealias CodingKeysType = CodingKeys

    public init(from decoder: Decoder) throws {
        try Self.checkKeys(using: decoder)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        let address = try ServerAddress(try values.decode(String.self, forKey: .address))
        let type = try values.decode(ServerType.self, forKey: .type)
        let tags = try values.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
        let maxWireVersion = try values.decodeIfPresent(Int.self, forKey: .maxWireVersion)

        var lastUpdateTime: Date?
        if let lastUpdateTimeMS = try values.decodeIfPresent(Int64.self, forKey: .lastUpdateTime) {
            lastUpdateTime = Date(msSinceEpoch: lastUpdateTimeMS)
        }

        // lastWriteDate is specified in a document in the form described in the error message below
        var lastWriteDate: Date?
        if let lastWrite = try values.decodeIfPresent(BSONDocument.self, forKey: .lastWrite) {
            guard let lastWriteDateMS = lastWrite["lastWriteDate"]?.int64Value else {
                throw DecodingError.dataCorruptedError(
                    forKey: .lastWrite,
                    in: values,
                    debugDescription: "lastWrite should be specified in the form"
                        + " lastWrite: { lastWriteDate: { \"$numberLong\": value } }"
                )
            }
            lastWriteDate = Date(msSinceEpoch: lastWriteDateMS)
        }

        // TODO: SWIFT-1461: decode and set averageRoundTripTimeMS

        self.init(
            address: address,
            type: type,
            tags: tags,
            lastWriteDate: lastWriteDate,
            maxWireVersion: maxWireVersion,
            lastUpdateTime: lastUpdateTime
        )
    }

    internal enum CodingKeys: String, CodingKey, CaseIterable {
        case address, type, tags, averageRoundTripTimeMS = "avg_rtt_ms", lastWrite, maxWireVersion, lastUpdateTime
    }
}
