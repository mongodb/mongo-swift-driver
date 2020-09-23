@testable import struct MongoSwift.ReadPreference
import MongoSwiftSync

extension MongoDatabaseOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try container.decodeIfPresent(ReadConcern.self, forKey: .readConcern)
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try container.decodeIfPresent(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, readPreference: readPreference, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, readPreference, writeConcern
    }
}

extension MongoCollectionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try container.decodeIfPresent(ReadConcern.self, forKey: .readConcern)
        let writeConcern = try container.decodeIfPresent(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, writeConcern
    }
}

extension ClientSessionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let causalConsistency = try container.decodeIfPresent(Bool.self, forKey: .causalConsistency)
        let defaultTransactionOptions = try container.decodeIfPresent(
            TransactionOptions.self,
            forKey: .defaultTransactionOptions
        )
        self.init(causalConsistency: causalConsistency, defaultTransactionOptions: defaultTransactionOptions)
    }

    private enum CodingKeys: CodingKey {
        case causalConsistency, defaultTransactionOptions
    }
}

extension TransactionOptions: Decodable {
    public init(from decoder: Decoder) throws {
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

    private enum CodingKeys: CodingKey {
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

extension MongoClientOptions: Decodable {
    private enum CodingKeys: String, CodingKey {
        case retryReads, retryWrites, w, readConcernLevel, readPreference, heartbeatFrequencyMS
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? ReadConcern.other(container.decode(String.self, forKey: .readConcernLevel))
        let readPreference = try container.decodeIfPresent(ReadPreference.self, forKey: .readPreference)
        let retryReads = try container.decodeIfPresent(Bool.self, forKey: .retryReads)
        let retryWrites = try container.decodeIfPresent(Bool.self, forKey: .retryWrites)
        let writeConcern = try? WriteConcern(w: container.decode(WriteConcern.W.self, forKey: .w))
        let heartbeatFrequencyMS = try container.decodeIfPresent(Int.self, forKey: .heartbeatFrequencyMS)
        self.init(
            heartbeatFrequencyMS: heartbeatFrequencyMS,
            readConcern: readConcern,
            readPreference: readPreference,
            retryReads: retryReads,
            retryWrites: retryWrites,
            writeConcern: writeConcern
        )
    }
}
