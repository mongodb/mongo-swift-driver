/// The response document type from a `ChangeStream`.
public struct ChangeStreamDocument<T: Codable>: Codable {
	public struct UpdateDescription: Codable {
        /// A document containing key:value pairs of names of the fields
        /// that were changed, and the new value for those fields.
        public let updatedFields: Document

        /// An array of field names that were removed from the document.
        public let removedFields: [String]
    }

    /// An enum representing the type of operation for this change.
     public enum OperationType: String, Codable {
        case insert
        case update
        case replace
        case delete
        case invalidate
        case drop
        case dropDatabase
        case rename
     }

    /// Describes the type of operation for this change.
    public let operationType: OperationType

    /// An opaque token for use when resuming an interrupted change
    /// stream.
    public let _id: ChangeStreamToken

    /// A document containing the database and collection names in
    /// which this change happened.
    public let ns: MongoNamespace

    /** Only present for options of type ‘insert’, ‘update’,
      * ‘replace’ and ‘delete’.
      *
      * For unsharded collections this contains a single field, _id, with the
      * value of the _id of the document updated. For sharded collections,
      * this will contain all the components of the shard key in order,
      * followed by the _id if the _id isn’t part of the shard key.
      */
    public let documentKey: Document?

    /// An `UpdateDescription` containing updated and removed fields in
    /// this operation. Only present for operations of type `update`.
    public let updateDescription: UpdateDescription?

   /**
    * Always present for operations of type ‘insert’ and ‘replace’. Also
    * present for operations of type ‘update’ if the user has specified
    * ‘updateLookup’ in the ‘fullDocument’ arguments to the ‘$changeStream’
    *  stage.
    *
    * For operations of type ‘insert’ and ‘replace’, this key will contain
    * the document being inserted, or the new version of the document that is
    * replacing the existing document, respectively.
    *
    * For operations of type ‘update’, this key will contain a copy of the
    * full version of the document from some point after the update occurred.
    * If the document was deleted since the updated happened, it will be
    * null.
    */
    public let fullDocument: T?
 }
