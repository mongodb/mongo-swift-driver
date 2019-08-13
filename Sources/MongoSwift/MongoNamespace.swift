/// Represents a MongoDB namespace for a database or collection.
public struct MongoNamespace: Codable, Equatable {
    /// The database name.
    public let db: String
    /// The collection name if this is a collection's namespace, or nil otherwise.
    public let collection: String?

    private enum CodingKeys: String, CodingKey {
        case db, collection = "coll"
    }
}

extension MongoNamespace: CustomStringConvertible {
    public var description: String {
        guard let collection = self.collection else {
            return self.db
        }
        return "\(self.db).\(collection)"
    }
}
