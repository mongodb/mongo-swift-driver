import CLibMongoC

/// MongoSwift only supports MongoDB 3.6+.
internal let MIN_SUPPORTED_WIRE_VERSION = 6

private final class MongocInitializer {
    internal static let shared = MongocInitializer()

    private init() {
        mongoc_init()
        mongoc_log_set_handler(handleMongocLogMessage, nil)
        mongoc_structured_log_set_handler(handleMongocStructuredLogMessage, nil)
        mongoc_handshake_data_append("MongoSwift", MongoSwiftVersionString, nil)
    }
}

/// Initializes libmongoc. Repeated calls to this method have no effect.
internal func initializeMongoc() {
    _ = MongocInitializer.shared
}

/**
 * Release all internal memory and other resources allocated by MongoSwift.
 *
 * This function should be called once at the end of the application. Users
 * should not interact with the driver after calling this function.
 */
public func cleanupMongoSwift() {
    /* Note: ideally, this would be called from MongocInitializer's deinit,
     * but Swift does not currently handle deinitialization of singletons.
     * See: https://bugs.swift.org/browse/SR-2500 */
    mongoc_cleanup()
}
