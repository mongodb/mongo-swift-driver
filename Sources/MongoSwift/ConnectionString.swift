import CLibMongoC

/// Class representing a connection string for connecting to MongoDB.
internal class ConnectionString {
    /// Pointer to the underlying `mongoc_uri_t`.
    private let _uri: OpaquePointer
    /// Tracks whether we have already destroyed the above pointer.
    private var destroyedPtr = false

    /// Minimum possible value for a heartbeatFrequencyMS specified via the URI or options.
    /// This may be overridden in the tests via an internal option on `MongoClientOptions`.
    internal var minHeartbeatFrequencyMS: Int32 = 500

    /// Initializes a new `ConnectionString` with the provided options.
    internal init(_ connectionString: String, options: MongoClientOptions? = nil) throws {
        // Initialize mongoc. Repeated calls have no effect so this is safe to do every time.
        initializeMongoc()
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw extractMongoError(error: error)
        }
        self._uri = uri

        // Due to SR-13355, deinit does not get called if we throw here. If we encounter an error, we need to manually
        // clean up the pointer. We use a variable to track whether we already destroyed it so that, in the event the
        // bug is fixed and `deinit` starts being called, we don't start calling `mongoc_uri_destroy` twice.
        do {
            try self.applyAndValidateOptions(options)
        } catch {
            mongoc_uri_destroy(self._uri)
            self.destroyedPtr = true
            throw error
        }
    }

    private func applyAndValidateOptions(_ options: MongoClientOptions?) throws {
        try self.applyAndValidateAuthOptions(options)
        try self.applyAndValidateTLSOptions(options)
        try self.applyAndValidateConnectionPoolOptions(options)
        try self.applyAndValidateCompressionOptions(options)
        try self.applyAndValidateSDAMOptions(options)
        try self.applyAndValidateServerSelectionOptions(options)

        if let appName = options?.appName {
            try self.setUTF8Option(MONGOC_URI_APPNAME, to: appName)
        }

        if let rc = options?.readConcern {
            self.readConcern = rc
        }

        if let replicaSet = options?.replicaSet {
            try self.setUTF8Option(MONGOC_URI_REPLICASET, to: replicaSet)
        }

        if let rr = options?.retryReads {
            try self.setBoolOption(MONGOC_URI_RETRYREADS, to: rr)
        }

        if let rw = options?.retryWrites {
            try self.setBoolOption(MONGOC_URI_RETRYWRITES, to: rw)
        }

        if let wc = options?.writeConcern {
            self.writeConcern = wc
        }

        // libmongoc does not validate negative timeouts in the input string, so do it ourselves here.
        if let connectTimeoutMS = self.options?[MONGOC_URI_CONNECTTIMEOUTMS]?.int32Value, connectTimeoutMS < 1 {
            throw MongoError.InvalidArgumentError(
                message: "Invalid \(MONGOC_URI_CONNECTTIMEOUTMS): must be between 1 and \(Int32.max)"
            )
        }
        if let socketTimeoutMS = self.options?[MONGOC_URI_SOCKETTIMEOUTMS]?.int32Value, socketTimeoutMS < 0 {
            throw MongoError.InvalidArgumentError(
                message: "Invalid \(MONGOC_URI_SOCKETTIMEOUTMS): must be between 1 and \(Int32.max)"
            )
        }

        // We effectively disabled libmongoc's validation of this option to support setting lower heartbeat frequencies
        // in the tests, so we need to do the validation ourselves.
        if let heartbeatFrequencyMS = self.options?[MONGOC_URI_HEARTBEATFREQUENCYMS]?.int32Value {
            guard heartbeatFrequencyMS >= self.minHeartbeatFrequencyMS else {
                throw self.int32OutOfRangeError(
                    option: MONGOC_URI_HEARTBEATFREQUENCYMS,
                    value: heartbeatFrequencyMS,
                    min: self.minHeartbeatFrequencyMS,
                    max: Int32.max
                )
            }
        }
    }

    private func setBoolOption(_ name: String, to value: Bool) throws {
        guard mongoc_uri_set_option_as_bool(self._uri, name, value) else {
            throw self.failedToSet(name, to: value)
        }
    }

    private func setUTF8Option(_ name: String, to value: String, redactInErrorMsg: Bool = false) throws {
        guard mongoc_uri_set_option_as_utf8(self._uri, name, value) else {
            throw self.failedToSet(name, to: value, redact: redactInErrorMsg)
        }
    }

    private func setInt32Option(_ name: String, to value: Int32) throws {
        guard mongoc_uri_set_option_as_int32(self._uri, name, value) else {
            throw self.failedToSet(name, to: value)
        }
    }

    /// Constructs a standardized error message about failing to set an option to a specified value. If redact=true the
    /// value will be omitted from the message.
    private func failedToSet(
        _ option: String,
        to value: CustomStringConvertible,
        redact: Bool = false
    ) -> MongoError.InvalidArgumentError {
        let msg = redact ? "Failed to set \(option)" : "Failed to set \(option) to \(value)"
        return MongoError.InvalidArgumentError(message: msg)
    }

    private func unsupportedOption(_ name: String) -> MongoError.InvalidArgumentError {
        MongoError.InvalidArgumentError(message: "Unsupported connection string option \(name)")
    }

    private func int32OutOfRangeError(
        option: String,
        value: CustomStringConvertible,
        min: Int32,
        max: Int32
    ) -> MongoError.InvalidArgumentError {
        MongoError.InvalidArgumentError(
            message: "Invalid \(option) \(value): must be between \(min) and \(max)"
        )
    }

    /// Sets and validates TLS-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateTLSOptions(_ options: MongoClientOptions?) throws {
        if let tls = options?.tls {
            // in parsing, libmongoc canonicalizes instances of "ssl" and replaces them with TLS. therefore, there is
            // no possibility that our setting the TLS option here creates an invalid combination of conflicting values
            // for the SSL and TLS options. if such a conflict is present in the input string libmongoc will error.
            try self.setBoolOption(MONGOC_URI_TLS, to: tls)
        }

        if options?.tlsInsecure != nil || self.hasOption(MONGOC_URI_TLSINSECURE) {
            let errString = "and \(MONGOC_URI_TLSINSECURE) options cannot both be specified"

            // per URI options spec, we must raise an error if `tlsInsecure` is provided along with either of
            // `tlsAllowInvalidCertificates` or `tlsAllowInvalidHostnames`. if such a combination is provided in the
            // input connection string, libmongoc will error.
            if options?.tlsAllowInvalidCertificates != nil || self.hasOption(MONGOC_URI_TLSALLOWINVALIDCERTIFICATES) {
                throw MongoError.InvalidArgumentError(
                    message: "\(MONGOC_URI_TLSALLOWINVALIDCERTIFICATES) \(errString)"
                )
            }

            if options?.tlsAllowInvalidHostnames != nil || self.hasOption(MONGOC_URI_TLSALLOWINVALIDHOSTNAMES) {
                throw MongoError.InvalidArgumentError(
                    message: "\(MONGOC_URI_TLSALLOWINVALIDHOSTNAMES) \(errString)"
                )
            }
        }

        if let tlsInsecure = options?.tlsInsecure {
            try self.setBoolOption(MONGOC_URI_TLSINSECURE, to: tlsInsecure)
        }

        if let invalidCerts = options?.tlsAllowInvalidCertificates {
            try self.setBoolOption(MONGOC_URI_TLSALLOWINVALIDCERTIFICATES, to: invalidCerts)
        }

        if let invalidHostnames = options?.tlsAllowInvalidHostnames {
            try self.setBoolOption(MONGOC_URI_TLSALLOWINVALIDHOSTNAMES, to: invalidHostnames)
        }

        if let caFile = options?.tlsCAFile?.absoluteString {
            try self.setUTF8Option(MONGOC_URI_TLSCAFILE, to: caFile)
        }

        if let certFile = options?.tlsCertificateKeyFile?.absoluteString {
            try self.setUTF8Option(MONGOC_URI_TLSCERTIFICATEKEYFILE, to: certFile)
        }

        if let password = options?.tlsCertificateKeyFilePassword {
            try self.setUTF8Option(MONGOC_URI_TLSCERTIFICATEKEYFILEPASSWORD, to: password, redactInErrorMsg: true)
        }
    }

    /// Sets and validates authentication-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateAuthOptions(_ options: MongoClientOptions?) throws {
        guard let credential = options?.credential else {
            return
        }

        if let username = credential.username {
            guard mongoc_uri_set_username(self._uri, username) else {
                throw self.failedToSet("username", to: username)
            }
        }

        if let password = credential.password {
            guard mongoc_uri_set_password(self._uri, password) else {
                throw MongoError.InvalidArgumentError(message: "Failed to set password")
            }
        }

        if let authSource = credential.source {
            guard mongoc_uri_set_auth_source(self._uri, authSource) else {
                throw self.failedToSet(MONGOC_URI_AUTHSOURCE, to: authSource)
            }
        }

        if let mechanism = credential.mechanism {
            guard mongoc_uri_set_auth_mechanism(self._uri, mechanism.name) else {
                throw self.failedToSet(MONGOC_URI_AUTHMECHANISM, to: mechanism)
            }
        }

        try credential.mechanismProperties?.withBSONPointer { mechanismPropertiesPtr in
            guard mongoc_uri_set_mechanism_properties(self._uri, mechanismPropertiesPtr) else {
                let desc = String(describing: credential.mechanismProperties)
                throw self.failedToSet(MONGOC_URI_AUTHMECHANISMPROPERTIES, to: desc)
            }
        }
    }

    /// Sets and validates connection pool-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateConnectionPoolOptions(_ options: MongoClientOptions?) throws {
        if let maxPoolSize = options?.maxPoolSize {
            guard let value = Int32(exactly: maxPoolSize), value > 0 else {
                throw self.int32OutOfRangeError(
                    option: MONGOC_URI_MAXPOOLSIZE,
                    value: maxPoolSize,
                    min: 1,
                    max: Int32.max
                )
            }

            try self.setInt32Option(MONGOC_URI_MAXPOOLSIZE, to: value)
        }

        let unsupportedOptions = [
            // the way libmongoc has implemented minPoolSize is not in line with the way users would expect a
            // minPoolSize option to behave, so throw an error if we detect it to prevent users from
            // inadvertently using it. once we own our own connection pool we will implement this option correctly.
            // see: http://mongoc.org/libmongoc/current/mongoc_client_pool_min_size.html
            MONGOC_URI_MINPOOLSIZE,
            // libmongoc has reserved all of these as known options keywords so no warnings are generated, however they
            // actually have no effect, so we should prevent users from trying to use them.
            MONGOC_URI_MAXIDLETIMEMS,
            MONGOC_URI_WAITQUEUEMULTIPLE,
            MONGOC_URI_WAITQUEUETIMEOUTMS
        ]

        for option in unsupportedOptions where self.hasOption(option) {
            throw unsupportedOption(option)
        }
    }

    /// Sets and validates compression-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateCompressionOptions(_ options: MongoClientOptions?) throws {
        if let compressors = options?.compressors {
            // user specified an empty array, so we should nil out any compressors set via connection string.
            guard !compressors.isEmpty else {
                guard mongoc_uri_set_compressors(self._uri, nil) else {
                    throw self.failedToSet("compressors", to: "nil")
                }
                return
            }

            // otherwise, the only valid inputs is a length 1 array containing either zlib or zlib with a level.
            guard compressors.count == 1 else {
                throw MongoError.InvalidArgumentError(message: "zlib compressor provided multiple times")
            }

            let compressor = compressors[0]
            switch compressor._compressor {
            case let .zlib(level):
                guard mongoc_uri_set_compressors(self._uri, "zlib") else {
                    throw self.failedToSet("compressor", to: "zlib")
                }

                if let level = level {
                    try self.setInt32Option(MONGOC_URI_ZLIBCOMPRESSIONLEVEL, to: level)
                }
            }
        }
    }

    /// Sets and validates SDAM-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateSDAMOptions(_ options: MongoClientOptions?) throws {
        // Per SDAM spec: If the ``directConnection`` option is not specified, newly developed drivers MUST behave as
        // if it was specified with the false value.
        if let dc = options?.directConnection {
            guard !(dc && self.usesDNSSeedlistFormat) else {
                throw MongoError.InvalidArgumentError(
                    message: "\(MONGOC_URI_DIRECTCONNECTION)=true is incompatible with mongodb+srv connection strings"
                )
            }

            if let hosts = self.hosts {
                guard !(dc && hosts.count > 1) else {
                    throw MongoError.InvalidArgumentError(
                        message: "\(MONGOC_URI_DIRECTCONNECTION)=true is incompatible with multiple seeds. " +
                            "got seeds: \(hosts)"
                    )
                }
            }

            try self.setBoolOption(MONGOC_URI_DIRECTCONNECTION, to: dc)
        } else if !self.hasOption(MONGOC_URI_DIRECTCONNECTION) {
            try self.setBoolOption(MONGOC_URI_DIRECTCONNECTION, to: false)
        }

        if let minHeartbeatFreqMS = options?.minHeartbeatFrequencyMS {
            self.minHeartbeatFrequencyMS = Int32(minHeartbeatFreqMS)
        }

        if let heartbeatFreqMS = options?.heartbeatFrequencyMS {
            guard let value = Int32(exactly: heartbeatFreqMS), value >= self.minHeartbeatFrequencyMS else {
                throw self.int32OutOfRangeError(
                    option: MONGOC_URI_HEARTBEATFREQUENCYMS,
                    value: heartbeatFreqMS,
                    min: self.minHeartbeatFrequencyMS,
                    max: Int32.max
                )
            }

            try self.setInt32Option(MONGOC_URI_HEARTBEATFREQUENCYMS, to: value)
        }
    }

    /// Sets and validates server selection-related on the underlying `mongoc_uri_t`.
    private func applyAndValidateServerSelectionOptions(_ options: MongoClientOptions?) throws {
        if let localThresholdMS = options?.localThresholdMS {
            guard let value = Int32(exactly: localThresholdMS), value >= 0 else {
                throw self.int32OutOfRangeError(
                    option: MONGOC_URI_LOCALTHRESHOLDMS,
                    value: localThresholdMS,
                    min: 0,
                    max: Int32.max
                )
            }

            try self.setInt32Option(MONGOC_URI_LOCALTHRESHOLDMS, to: value)

            // libmongoc does not validate an invalid value for localThresholdMS set via URI. if it was set that way and
            // not overridden via options struct, validate it ourselves here.
        } else if let uriValue = self.options?[MONGOC_URI_LOCALTHRESHOLDMS]?.int32Value, uriValue < 0 {
            throw self.int32OutOfRangeError(
                option: MONGOC_URI_LOCALTHRESHOLDMS,
                value: uriValue,
                min: 0,
                max: Int32.max
            )
        }

        if let ssTimeout = options?.serverSelectionTimeoutMS {
            guard let value = Int32(exactly: ssTimeout), value > 0 else {
                throw self.int32OutOfRangeError(
                    option: MONGOC_URI_SERVERSELECTIONTIMEOUTMS,
                    value: ssTimeout,
                    min: 1,
                    max: Int32.max
                )
            }

            try self.setInt32Option(MONGOC_URI_SERVERSELECTIONTIMEOUTMS, to: value)
        } else if let uriValue = self.options?[MONGOC_URI_SERVERSELECTIONTIMEOUTMS]?.int32Value, uriValue <= 0 {
            throw self.int32OutOfRangeError(
                option: MONGOC_URI_SERVERSELECTIONTIMEOUTMS,
                value: uriValue,
                min: 1,
                max: Int32.max
            )
        }

        if let rp = options?.readPreference {
            self.readPreference = rp
        } else if let maxStaleness = self.options?[MONGOC_URI_MAXSTALENESSSECONDS]?.int32Value,
            maxStaleness < MONGOC_SMALLEST_MAX_STALENESS_SECONDS {
            throw MongoError.InvalidArgumentError(
                message: "Invalid \(MONGOC_URI_MAXSTALENESSSECONDS) \(maxStaleness): " +
                    "must be at least \(MONGOC_SMALLEST_MAX_STALENESS_SECONDS)"
            )
        }
    }

    /// Initializes a new connection string that wraps a copy of the provided URI. Does not destroy the input URI.
    internal init(copying uri: OpaquePointer) {
        self._uri = mongoc_uri_copy(uri)
    }

    /// Cleans up the underlying `mongoc_uri_t`.
    deinit {
        if !self.destroyedPtr {
            mongoc_uri_destroy(self._uri)
        }
    }

    private var usesDNSSeedlistFormat: Bool {
        // This method returns a string if this URI’s scheme is “mongodb+srv://”, or NULL if the scheme is
        // “mongodb://”.
        mongoc_uri_get_service(self._uri) != nil
    }

    /// The `ReadConcern` for this connection string.
    internal var readConcern: ReadConcern {
        get {
            ReadConcern(copying: mongoc_uri_get_read_concern(self._uri))
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
            WriteConcern(copying: mongoc_uri_get_write_concern(self._uri))
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
            ReadPreference(copying: mongoc_uri_get_read_prefs_t(self._uri))
        }
        set(rp) {
            rp.withMongocReadPreference { rpPtr in
                mongoc_uri_set_read_prefs_t(self._uri, rpPtr)
            }
        }
    }

    /// Returns the username if one was provided, otherwise nil.
    internal var username: String? {
        guard let username = mongoc_uri_get_username(self._uri) else {
            return nil
        }
        return String(cString: username)
    }

    /// Returns the password if one was provided, otherwise nil.
    internal var password: String? {
        guard let pw = mongoc_uri_get_password(self._uri) else {
            return nil
        }
        return String(cString: pw)
    }

    /// Returns the auth database if one was provided, otherwise nil.
    internal var authSource: String? {
        guard let source = mongoc_uri_get_auth_source(self._uri) else {
            return nil
        }
        return String(cString: source)
    }

    /// Returns the auth mechanism if one was provided, otherwise nil.
    internal var authMechanism: MongoCredential.Mechanism? {
        guard let mechanism = mongoc_uri_get_auth_mechanism(self._uri) else {
            return nil
        }
        let str = String(cString: mechanism)
        return MongoCredential.Mechanism(str)
    }

    /// Returns a document containing the auth mechanism properties if any were provided, otherwise nil.
    internal var authMechanismProperties: BSONDocument? {
        var props = bson_t()
        return withUnsafeMutablePointer(to: &props) { propsPtr in
            guard mongoc_uri_get_mechanism_properties(self._uri, propsPtr) else {
                return nil
            }
            /// This copy should not be returned directly as its only guaranteed valid for as long as the
            /// `mongoc_uri_t`, as `props` was statically initialized from data stored in the URI and may contain
            /// pointers that will be invalidated once the URI is.
            let copy = BSONDocument(copying: propsPtr)

            return copy.mapValues { value in
                // mongoc returns boolean options e.g. CANONICALIZE_HOSTNAME as strings, but they are boolean values.
                switch value {
                case "true":
                    return true
                case "false":
                    return false
                default:
                    return value
                }
            }
        }
    }

    /// Returns the credential configured on this URI. Will be empty if no options are set.
    internal var credential: MongoCredential {
        MongoCredential(
            username: self.username,
            password: self.password,
            source: self.authSource,
            mechanism: self.authMechanism,
            mechanismProperties: self.authMechanismProperties
        )
    }

    internal var db: String? {
        guard let db = mongoc_uri_get_database(self._uri) else {
            return nil
        }
        return String(cString: db)
    }

    /// Returns a document containing all of the options provided after the ? of the URI.
    internal var options: BSONDocument? {
        guard let optsDoc = mongoc_uri_get_options(self._uri) else {
            return nil
        }
        var copy = BSONDocument(copying: optsDoc)

        if let authSource = self.authSource {
            copy.authsource = .string(authSource)
        }
        if let authMechanism = self.authMechanism {
            copy.authmechanism = .string(authMechanism.name)
        }
        if let authMechanismProperties = self.authMechanismProperties {
            copy.authmechanismproperties = .document(authMechanismProperties)
        }
        if let parsedTagSets = self.readPreference.tagSets {
            copy.readpreferencetags = .array(parsedTagSets.map { BSON.document($0) })
        }
        if let compressors = self.compressors {
            copy.compressors = .array(compressors.map { .string($0) })
        }
        if let readConcern = self.readConcern.level {
            copy.readconcernlevel = .string(readConcern)
        }

        return copy
    }

    /// Returns the host/port pairs specified in the connection string, or nil if this connection string's scheme is
    /// “mongodb+srv://”.
    internal var hosts: [ServerAddress]? {
        guard let hostList = mongoc_uri_get_hosts(self._uri) else {
            return nil
        }

        var hosts = [ServerAddress]()
        var next = hostList

        while true {
            hosts.append(ServerAddress(next))

            guard let nextPointer = next.pointee.next else {
                break
            }
            next = UnsafePointer(nextPointer)
        }

        return hosts
    }

    internal var compressors: [String]? {
        guard let compressors = mongoc_uri_get_compressors(self._uri) else {
            return nil
        }
        return BSONDocument(copying: compressors).keys
    }

    internal var replicaSet: String? {
        guard let rs = mongoc_uri_get_replica_set(self._uri) else {
            return nil
        }
        return String(cString: rs)
    }

    internal var appName: String? {
        guard let appName = mongoc_uri_get_option_as_utf8(self._uri, MONGOC_URI_APPNAME, nil) else {
            return nil
        }
        return String(cString: appName)
    }

    private func hasOption(_ option: String) -> Bool {
        mongoc_uri_has_option(self._uri, option)
    }

    /// Executes the provided closure using a pointer to the underlying `mongoc_uri_t`.
    internal func withMongocURI<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        try body(self._uri)
    }
}
