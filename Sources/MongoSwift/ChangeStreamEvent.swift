/// An `UpdateDescription` containing fields that will be present in the change stream document for
/// operations of type `update`.
public struct UpdateDescription: Codable {
    /**
     * A document containing key:value pairs of names of the fields that were changed (excluding the fields reported
     * via `truncatedArrays`), and the new value for those fields.
     *
     * Despite array fields reported via `truncatedArrays` being excluded from this field, changes to fields of the
     * elements of the array values may be reported via this field.
     *
     * Example:
     *   original field:
     *     "arrayField": ["foo", {"a": "bar"}, 1, 2, 3]
     *   updated field:
     *     "arrayField": ["foo", {"a": "bar", "b": 3}]
     *   a potential corresponding UpdateDescription:
     *     UpdateDescription(
     *       updatedFields: {
     *         "arrayField.1.b": 3
     *       },
     *       removedFields: [],
     *       truncatedArrays: [
     *         TruncatedArrayDescription(
     *           field: "arrayField",
     *           newSize: 2
     *         )
     *       ]
     *     )
     *
     * Modifications to array elements are expressed via dot notation.
     * Example: an `update` which sets the element with index 0 in the array field named arrayField to 7 is reported as
     *   "updatedFields": {"arrayField.0": 7}
     *
     * - SeeAlso: https://docs.mongodb.com/manual/core/document/#document-dot-notation
     */
    public let updatedFields: BSONDocument

    /// An array of field names that were removed from the document.
    public let removedFields: [String]

    /// Describes an array that was truncated via an update operation.
    public struct TruncatedArrayDescription: Codable {
        /// The name of the array field which was truncated.
        public let field: String
        /// The new size of the array.
        public let newSize: Int
    }

    /**
     * Truncations of arrays may be reported either via this field or via the ‘updatedFields’ field. In the latter
     * case, the entire array is considered to be replaced. The method used to report a truncation is a server
     * implementation detail.
     *
     * Example: an `update` which shrinks the array `arrayField.0.nestedArrayField` from size 8 to 5 may be reported
     * via this field as [TruncatedArrayDescription(field: "arrayField.0.nestedArrayField", newSize: 5)].
     *
     * This property will only ever be present on MongoDB server versions >= 5.0.
     */
    public let truncatedArrays: [TruncatedArrayDescription]?
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
    /// A  `MongoNamespace` containing the database and collection names in which this change happened.
    public let ns: MongoNamespace

    /// A `MongoNamespace` containing the new database and collection names for which the `rename` event happened.
    public let to: MongoNamespace?

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
        case operationType, _id, ns, to, documentKey, updateDescription, fullDocument
    }

    // Custom decode method to work around the fact that `invalidate` events do not have an `ns` field in the raw
    // document. TODO: SWIFT-981: Remove this.
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

        // `to` only exists in `rename` events else `nil` to resolve compiler error
        if self.operationType == OperationType.rename {
            self.to = try container.decode(MongoNamespace.self, forKey: .to)
        } else {
            self.to = nil
        }

        self.documentKey = try container.decodeIfPresent(BSONDocument.self, forKey: .documentKey)
        self.updateDescription = try container.decodeIfPresent(UpdateDescription.self, forKey: .updateDescription)
        self.fullDocument = try container.decodeIfPresent(T.self, forKey: .fullDocument)
    }
}
