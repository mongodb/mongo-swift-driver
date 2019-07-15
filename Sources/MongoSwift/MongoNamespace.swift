/// Represents a MongoDB namespace for a database or collection.
public struct MongoNamespace: Codable {
    public let db: String
    public let collection: String?

    public enum CodingKeys: String, CodingKey {
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
