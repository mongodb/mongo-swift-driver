import Foundation

/// An index to "hint" or force MongoDB to use when performing a query.
public enum IndexHint: Codable, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral {
    /// Specifies an index to use by its name.
    case indexName(String)
    /// Specifies an index to use by a specification `BSONDocument` containing the index key(s).
    case indexSpec(BSONDocument)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .indexName(name):
            try container.encode(name)
        case let .indexSpec(doc):
            try container.encode(doc)
        }
    }

    public init(stringLiteral value: StringLiteralType) {
        self = .indexName(value)
    }

    public init(dictionaryLiteral keyValuePairs: (String, BSON)...) {
        var docs = BSONDocument()
        for (k, v) in keyValuePairs {
            docs[k] = v
        }
        self = .indexSpec(docs)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .indexName(str)
        } else {
            self = .indexSpec(try container.decode(BSONDocument.self))
        }
    }
}
