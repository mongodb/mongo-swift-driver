import MongoSwiftSync

extension DatabaseOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let readPreference = try? container.decode(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, readPreference: readPreference, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, readPreference, writeConcern
    }
}

extension CollectionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
        self.init(readConcern: readConcern, writeConcern: writeConcern)
    }

    private enum CodingKeys: CodingKey {
        case readConcern, writeConcern
    }
}

extension ClientSessionOptions: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let causalConsistency = try? container.decode(Bool.self, forKey: .causalConsistency)
        let defaultTransactionOptions = try? container.decode(
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
        let maxCommitTimeMS = try? container.decode(Int64.self, forKey: .maxCommitTimeMS)
        let readConcern = try? container.decode(ReadConcern.self, forKey: .readConcern)
        let readPreference = try? container.decode(ReadPreference.self, forKey: .readPreference)
        let writeConcern = try? container.decode(WriteConcern.self, forKey: .writeConcern)
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
