import libmongoc

public struct ClientOptions {
  /// Determines whether the client should retry supported write operations
  let retryWrites: Bool?
}

public struct ListDatabasesOptions: BsonEncodable {
  /// An optional filter for the returned databases
  let filter: Document?

  /// Optionally indicate whether only names should be returned
  let nameOnly: Bool?

  /// An optional session to use for this operation
  let session: ClientSession?

  public func encode(to encoder: BsonEncoder) throws {
    try encoder.encode(filter, forKey: "filter")
    try encoder.encode(nameOnly, forKey: "nameOnly")
    try encoder.encode(session, forKey: "session")
  }
}

public enum MongoError: Error {
  case invalidUri(message: String)
  case invalidClient()
  case invalidResponse()
  case invalidCursor()
}

// A MongoDB Client
public class Client {
  private var _client = OpaquePointer(bitPattern: 1)

  /**
   * Create a new client connection to a MongoDB server
   *
   * - Parameters:
   *   - connectionString: the connection string to connect to
   *   - options: optional settings
   */
  public init(connectionString: String = "mongodb://localhost:27017", options: ClientOptions? = nil) throws {
    var error = bson_error_t()
    guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
      let errorMessage = withUnsafeBytes(of: &error.message) { (rawPtr) -> String in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
      }

      throw MongoError.invalidUri(message: errorMessage)
    }

    self._client = mongoc_client_new_from_uri(uri)
    if self._client == nil {
      throw MongoError.invalidClient()
    }
  }

  /**
   * Cleanup the internal mongoc_client_t
   */
  deinit {
    close()
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
    guard let client = self._client else {
      return
    }

    mongoc_client_destroy(client)
    self._client = nil
  }

  /**
   * Get a list of databases
   *
   * - Parameters:
   *   - options: Optional settings
   *
   * - Returns: A cursor over documents describing the databases matching provided criteria
   */
  func listDatabases(options: ListDatabasesOptions? = nil) throws -> Cursor {
    var error = bson_error_t()
    guard let cursor = mongoc_client_find_databases(self._client, &error) else {
      throw MongoError.invalidResponse()
    }

    return Cursor(fromCursor: cursor)
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
