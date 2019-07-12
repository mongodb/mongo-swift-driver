import CLibMongoC

/// Class representing a connection string for connecting to MongoDB.
internal class ConnectionString {
    /// Pointer to the underlying `mongoc_uri_t`.
    internal let _uri: OpaquePointer

    /// Initializes a new `ConnectionString` with the provided options.
    internal init(_ connectionString: String, options: ClientOptions? = nil) throws {
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw extractMongoError(error: error)
        }
        self._uri = uri

        if let rc = options?.readConcern {
            self.readConcern = rc
        }

        if let wc = options?.writeConcern {
            self.writeConcern = wc
        }

        if let rp = options?.readPreference {
            self.readPreference = rp
        }

        if let rw = options?.retryWrites {
            mongoc_uri_set_option_as_bool(self._uri, MONGOC_URI_RETRYWRITES, rw)
        }

        if let rr = options?.retryReads {
            mongoc_uri_set_option_as_bool(self._uri, MONGOC_URI_RETRYREADS, rr)
        }
    }

    /// Cleans up the underlying `mongoc_uri_t`.
    deinit {
        mongoc_uri_destroy(self._uri)
    }

    /// The `ReadConcern` for this connection string.
    internal var readConcern: ReadConcern {
        get {
            return ReadConcern(from: mongoc_uri_get_read_concern(self._uri))
        }
        set(rc) {
            rc.withMongocReadConcern { rcPtr in
                mongoc_uri_set_read_concern(self._uri, rcPtr)
            }
        }
    }

    /// The `WriteConcern` for this connection string.
    internal var writeConcern: WriteConcern {
        get {
            return WriteConcern(from: mongoc_uri_get_write_concern(self._uri))
        }
        set(wc) {
            wc.withMongocWriteConcern { wcPtr in
                mongoc_uri_set_write_concern(self._uri, wcPtr)
            }
        }
    }

    /// The `ReadPreference` for this connection string.
    internal var readPreference: ReadPreference {
        get {
            return ReadPreference(from: mongoc_uri_get_read_prefs_t(self._uri))
        }
        set(rp) {
            mongoc_uri_set_read_prefs_t(self._uri, rp._readPreference)
        }
    }
}
