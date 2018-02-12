public struct ClientOptions {
    /// Determines whether the client should retry supported write operations
    let retryWrites: Bool?
}

public struct ListDatabasesOptions {
    /// An optional filter for the returned databases
    let filter: Document?

    /// Optionally indicate whether only names should be returned
    let nameOnly: Bool?

    /// An optional session to use for this operation
    let session: ClientSession?
}

// A MongoDB Client
public class Client {
    /**
     * Create a new client connection to a MongoDB server
     *
     * - Parameters:
     *   - connectionString: the connection string to connect to
     *   - options: optional settings
     */
    public init(connectionString: String? = nil, options: ClientOptions? = nil) {
    }

    /**
     * Cleanup the internal mongoc_client_t
     */
    deinit {
    }

    /**
     * Creates a client session
     *
     * - Parameters:
     *   - options: The options to use to create the client session
     *
     * - Returns: A `ClientSession` instance
     */
    func startSession(options: SessionOptions) throws -> ClientSession {
        return ClientSession()
    }

    /**
     * Close the client
     */
    func close() {
    }

    /**
     * Get a list of databases
     *
     * - Parameters:
     *   - options: Optional settings
     *
     * - Returns: An cursor over documents describing the databases matching provided criteria
     */
    func listDatabases(options: ListDatabasesOptions? = nil) throws -> Cursor {
        return Cursor()
    }

    /**
     * Gets a Database instance for the given database name.
     *
     * - Parameters:
     *   - name: the name of the database to retrieve
     *
     * - Returns: a `Database` corresponding to the provided database name
     */
    func db(name: String) throws -> Database {
        return Database()
    }
}
