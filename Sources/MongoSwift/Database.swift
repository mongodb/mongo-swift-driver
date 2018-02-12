public struct RunCommandOptions {
    /// A session to associate with this operation
    let session: ClientSession?
}

public struct ListCollectionsOptions {
    /// A filter to match collections against
    let filter: Document?

    /// The batchSize for the returned cursor
    let batchSize: Int?

    /// A session to associate with this operation
    let session: ClientSession?
}

public struct CreateCollectionOptions {
    /// Indicates whether this will be a capped collection
    let capped: Bool?

    /// Whether or not this collection will automatically generate an index on _id
    let autoIndexId: Bool?

    /// Maximum size, in bytes, of this collection (if capped)
    let size: Int64?

    /// Maximum number of documents allowed in the collection (if capped)
    let max: Int64?

    /// Determine which storage engine to use
    let storageEngine: Document?

    /// What validator should be used for the collection
    let validator: Document?

    /// Determines how strictly MongoDB applies the validation rules to existing documents during an update
    let validationLevel: String?

    /// Determines whether to error on invalid documents or just warn about the violations
    /// but allow invalid documents to be inserted
    let validationAction: String?

    /// Allows users to specify a default configuration for indexes when creating a collection
    let indexOptionDefaults: Document?

    /// The name of the source collection or view from which to create the view
    let viewOn: String?

    /// Specifies the default collation for the collection
    let collation: Document?

    /// A session to associate with this operation
    let session: ClientSession?
}

// A MongoDB Database
public class Database {

    /**
     * Initializes a new Database instance, not meant to be instantiated directly
     */
    public init() {
    }

    /**
     * Deinitializes a Database, cleaning up the internal mongoc_database_t
     */
    deinit {
    }

    /**
     * Access a collection within this database.
     *
     * - Parameters:
     *   - name: the name of the collection to get
     *
     * - Returns: the requested `Collection`
     */
    func collection(name: String) throws -> Collection {
        return Collection()
    }

    /**
     * Creates a collection in this database with the specified options
     *
     * - Parameters:
     *   - name: the name of the collection
     *   - options: optional settings
     *
     * - Returns: the newly created `Collection`
     */
    func createCollection(name: String, options: CreateCollectionOptions? = nil) throws -> Collection {
        return Collection()
    }

    /**
     * List all collections in this database
     *
     * - Parameters:
     *   - filter: Optional criteria to filter results by
     *   - options: Optional settings
     *
     * - Returns: a `Cursor` over an array of collections
     */
    func listCollections(options: ListCollectionsOptions? = nil) throws -> Cursor {
        return Cursor()
    }

    /**
     * Issue a MongoDB command against this database
     *
     * - Parameters:
     *   - command: The command to issue against the database
     *   - options: Optional settings
     *
     * - Returns: The server response for the command
     */
    func runCommand(command: Document, options: RunCommandOptions? = nil) throws -> Document {
        return Document()
    }
}
