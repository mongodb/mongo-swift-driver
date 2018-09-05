import libmongoc

/// A utility class for libmongoc initialization and cleanup.
public final class MongoSwift {
    /// The version of `MongoSwift`. 
    public static let versionString = "0.0.2"

    final class MongocInitializer {
        static let shared = MongocInitializer()

        private init() {
            mongoc_init()
            mongoc_handshake_data_append("MongoSwift", versionString, nil)
        }
    }

    /**
     * Initializes libmongoc.
     *
     * This function should be called once at the start of the application
     * before interacting with the driver.
     */
    public static func initialize() {
        _ = MongocInitializer.shared
    }

    /**
     * Cleans up libmongoc.
     *
     * This function should be called once at the end of the application. Users
     * should not interact with the driver after calling this function.
     */
    public static func cleanup() {
        /* Note: ideally, this would be called from MongocInitializer's deinit,
         * but Swift does not currently handle deinitialization of singletons.
         * See: https://bugs.swift.org/browse/SR-2500 */
        mongoc_cleanup()
    }
}
