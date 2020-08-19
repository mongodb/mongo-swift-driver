/// An `UpdateDescription` containing fields that will be present in the change stream document for
/// operations of type `update`.
public struct UpdateDescription: Codable {
    /// A document containing key:value pairs of names of the fields that were changed, and the new
    /// value for those fields.
    public let updatedFields: BSONDocument

    /// An array of field names that were removed from the document.
    public let removedFields: [String]
}

/// An enum representing the type of operation for this change event.
public enum OperationType: String, Codable {
    /// Specifies an operation of type `insert`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#insert-event
    case insert
    /// Specifies an operation of type `update`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#update-event
    case update
    /// Specifies an operation of type `replace`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#replace-event
    case replace
    /// Specifies an operation of type `delete`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#delete-event
    case delete
    /// Specifies an operation of type `invalidate`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#change-event-invalidate
    case invalidate
    /// Specifies an operation of type `drop`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#drop-event
    case drop
    /// Specifies an operation of type `dropDatabase`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#dropdatabase-event
    case dropDatabase
    /// Specifies an operation of type `rename`.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/change-events/index.html#rename-event
    case rename
}

/// The response document type from a `ChangeStream`.
public struct ChangeStreamEvent<T: Codable>: Codable {
    /// Describes the type of operation for this change.
    public let operationType: OperationType

    /// An opaque token for use when resuming an interrupted change stream.
    /// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/#resume-a-change-stream
    public let _id: ResumeToken

    // TODO: SWIFT-981: Make this field optional.
    /// A document containing the database and collection names in which this change happened.
    public let ns: MongoNamespace

    /**
     * Only present for options of type `insert`, `update`, `replace` and `delete`. For unsharded collections this
     * contains a single field, _id, with the value of the _id of the document updated. For sharded collections, this
     * will contain all the components of the shard key in order, followed by the _id if the _id isn’t part of the
     * shard key.
     */
    public let documentKey: BSONDocument?

    /// An `UpdateDescription` containing updated and removed fields in this operation. Only present for operations of
    /// type`update`.
    public let updateDescription: UpdateDescription?

    /**
     * Always present for operations of type `insert` and `replace`. Also present for operations of type `update` if
     * the user has specified `.updateLookup` for the `fullDocument` option in the `ChangeStreamOptions` used to create
     * the change stream that emitted this document.
     *
     * For operations of type `insert’ and `replace’, this key will contain the document being inserted, or the new
     * version of the document that is replacing the existing document, respectively.
     *
     * For operations of type `update’, this key will contain a copy of the full version of the document from some
     * point after the update occurred. If the document was deleted since the updated happened, it will be nil.
     */
    public let fullDocument: T?

    private enum CodingKeys: String, CodingKey {
        case operationType, _id, ns, documentKey, updateDescription, fullDocument
    }

    // Custom decode method to work around the fact that `invalidate` events do not have an `ns` field in the raw
    // document. TODO SWIFT-981: Remove this.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.operationType = try container.decode(OperationType.self, forKey: .operationType)
        self._id = try container.decode(ResumeToken.self, forKey: ._id)

        do {
            self.ns = try container.decode(MongoNamespace.self, forKey: .ns)
        } catch {
            guard let ns = decoder.userInfo[changeStreamNamespaceKey] as? MongoNamespace else {
                throw error
            }
            self.ns = ns
        }

        self.documentKey = try container.decodeIfPresent(BSONDocument.self, forKey: .documentKey)
        self.updateDescription = try container.decodeIfPresent(UpdateDescription.self, forKey: .updateDescription)
        self.fullDocument = try container.decodeIfPresent(T.self, forKey: .fullDocument)
    }
}
