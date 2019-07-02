/// Represents a MongoDB namespace for a database or collection.
internal struct MongoNamespace {
    internal let db: String
    internal let collection: String?
}

extension MongoNamespace: CustomStringConvertible {
    internal var description: String {
        guard let collection = self.collection else {
            return self.db
        }
        return "\(self.db).\(collection)"
    }
}
