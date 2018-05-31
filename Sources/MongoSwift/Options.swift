import Foundation

/// `ReadConcernable`, used for command options types, indicates that the
/// corresponding command supports using a read concern.
internal protocol ReadConcernable: Encodable {
    var readConcern: ReadConcern? { get set }
}

/// `MongoObject` is a protocol to group together `MongoClient`s, `MongoDatabase`s,
/// and `MongoCollection`s by common properties.
internal protocol MongoObject {
    var readConcern: ReadConcern? { get }
}

extension MongoClient: MongoObject {}
extension MongoDatabase: MongoObject {}
extension MongoCollection: MongoObject {}

extension MongoObject {
    /// Encodes `ReadConcernable` options types and handles logic for whether or not 
    /// the user's provided `ReadConcern` should be sent or omitted.
    func encodeOptions<T: ReadConcernable>(_ options: T?) throws -> Document? {
        guard var opts = options else { return nil }
        // if the RC provided for the command is the default, and the caller has
        // no RC/default RC, we must omit the RC when sending the command
        if opts.readConcern?.isDefault == true && self.readConcern == nil {
            opts.readConcern = nil
        }
        return try BsonEncoder().encode(opts)
    }

    /// Encodes options types that are just `Encodable`, and not `ReadConcernable`. 
    func encodeOptions<T: Encodable>(_ options: T?) throws -> Document? {
        return try BsonEncoder().encode(options)
    }
}
