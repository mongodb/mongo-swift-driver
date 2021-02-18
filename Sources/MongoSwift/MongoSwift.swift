import CLibMongoC

/// MongoSwift only supports MongoDB 3.6+.
internal let MIN_SUPPORTED_WIRE_VERSION = 6

/// Store optionally provided metadata about a library wrapping the driver.
private var clientMetadataLibraryName: String? 
private var clientMetadataLibraryVersion: String?

/// Adds metadata to include the in the handshake performed with the MongoDB server. This is intended for use by
/// libraries wrapping the driver e.g. MongoDBVapor or an ORM. If used, this method should be called exactly once.
/// This method will only have an effect if called before any `MongoClient`s are initialized.
public func addWrappingLibraryMetadata(name: String, version: String) {
    clientMetadataLibraryName = name
    clientMetadataLibraryVersion = version
}
private final class MongocInitializer {
    internal static let shared = MongocInitializer()

    private init() {
        mongoc_init()
        var libraryName = "MongoSwift"
        if let additionalName = clientMetadataLibraryName {
            libraryName += " / \(additionalName)"
        }

        var libraryVersion = MongoSwiftVersionString
        if let additionalVersion = clientMetadataLibraryVersion {
            libraryVersion += " / \(additionalVersion)"
        }

        mongoc_handshake_data_append(libraryName, libraryVersion, nil)
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
