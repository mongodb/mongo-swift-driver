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

extension ReadPreference.Mode: Decodable {}

extension ReadPreference: Decodable {
    private enum CodingKeys: String, CodingKey {
        case mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decode(Mode.self, forKey: .mode)
        self.init(mode)
    }
}

extension MongoClientOptions: Decodable {
    private enum CodingKeys: String, CodingKey {
        case retryReads, retryWrites, w, readConcernLevel, mode = "readPreference"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? ReadConcern.other(container.decode(String.self, forKey: .readConcernLevel))
        let readPreference = try? ReadPreference(container.decode(ReadPreference.Mode.self, forKey: .mode))
        let retryReads = try container.decodeIfPresent(Bool.self, forKey: .retryReads)
        let retryWrites = try container.decodeIfPresent(Bool.self, forKey: .retryWrites)
        let writeConcern = try? WriteConcern(w: container.decode(WriteConcern.W.self, forKey: .w))
        self.init(
            readConcern: readConcern,
            readPreference: readPreference,
            retryReads: retryReads,
            retryWrites: retryWrites,
            writeConcern: writeConcern
        )
    }
}
