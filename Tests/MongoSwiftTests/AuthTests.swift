import CLibMongoC
import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon

/// An extension adding accessors for a number of options that may be set on a `ConnectionString`.
extension ConnectionString {
    /// Returns the username if one was provided, otherwise nil.
    private var username: String? {
        guard let username = mongoc_uri_get_username(self._uri) else {
            return nil
        }
        return String(cString: username)
    }

    /// Returns the password if one was provided, otherwise nil.
    private var password: String? {
        guard let pw = mongoc_uri_get_password(self._uri) else {
            return nil
        }
        return String(cString: pw)
    }

    /// Returns the auth database if one was provided, otherwise nil.
    private var authSource: String? {
        guard let source = mongoc_uri_get_auth_source(self._uri) else {
            return nil
        }
        return String(cString: source)
    }

    /// Returns the auth mechanism if one was provided, otherwise nil.
    private var authMechanism: AuthMechanism? {
        guard let mechanism = mongoc_uri_get_auth_mechanism(self._uri) else {
            return nil
        }
        let str = String(cString: mechanism)
        return AuthMechanism(rawValue: str)
    }

    /// Returns a document containing the auth mechanism properties if any were provided, otherwise nil.
    private var authMechanismProperties: Document? {
        var props = bson_t()
        return withUnsafeMutablePointer(to: &props) { propsPtr in
            let opaquePtr = OpaquePointer(propsPtr)
            guard mongoc_uri_get_mechanism_properties(self._uri, opaquePtr) else {
                return nil
            }
            /// This copy should not be returned directly as its only guaranteed valid for as long as the
            /// `mongoc_uri_t`, as `props` was statically initialized from data stored in the URI and may contain
            /// pointers that will be invalidated once the URI is.
            let copy = Document(copying: opaquePtr)

            return copy.mapValues { value in
                // mongoc returns boolean options e.g. CANONICALIZE_HOSTNAME as strings, but they are booleans in the
                // spec test file.
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
    fileprivate var credential: Credential {
        return Credential(
            username: self.username,
            password: self.password,
            source: self.authSource,
            mechanism: self.authMechanism,
            mechanismProperties: self.authMechanismProperties
        )
    }
}

/// Represents a single file containing auth tests.
struct AuthTestFile: Decodable {
    let tests: [AuthTestCase]
}

/// Represents a single test case within a file.
struct AuthTestCase: Decodable {
    /// A string describing the test.
    let description: String
    /// A string containing the URI to be parsed.
    let uri: String
    /// A boolean indicating if the URI should be considered valid.
    let valid: Bool
    /// An authentication credential. If nil, the credential must not be considered configured for the purpose of
    /// deciding if the driver should authenticate to the topology.
    let credential: Credential?
}

/// Represents an authentication credential.
struct Credential: Decodable, Equatable {
    /// A string containing the username. For auth mechanisms that do not utilize a password, this may be the entire
    /// `userinfo` token from the connection string.
    let username: String?
    /// A string containing the password.
    let password: String?
    /// A string containing the authentication database.
    let source: String?
    /// The authentication mechanism. A nil value for this key is used to indicate that a mechanism wasn't specified
    /// and that mechanism negotiation is required.
    let mechanism: AuthMechanism?
    /// A document containing mechanism-specific properties.
    let mechanismProperties: Document?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
    }

    // TODO: SWIFT-636: remove this initializer and the one below it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.mechanism = try container.decodeIfPresent(AuthMechanism.self, forKey: .mechanism)

        // libmongoc does not return the service name if it's the default, but it is contained in the spec test files,
        // so filter it out here if it's present.
        let properties = try container.decodeIfPresent(Document.self, forKey: .mechanismProperties)
        let filteredProperties = properties?.filter { !($0.0 == "SERVICE_NAME" && $0.1 == "mongodb") }
        // if SERVICE_NAME was the only key then don't return an empty document.
        if filteredProperties?.isEmpty == true {
            self.mechanismProperties = nil
        } else {
            self.mechanismProperties = filteredProperties
        }
    }

    init(
        username: String?,
        password: String?,
        source: String?,
        mechanism: AuthMechanism?,
        mechanismProperties: Document?
    ) {
        self.mechanism = mechanism
        self.mechanismProperties = mechanismProperties
        self.password = password
        self.source = source
        self.username = username
    }
}

final class AuthTests: MongoSwiftTestCase {
    func testAuthConnectionStrings() throws {
        let testFiles = try retrieveSpecTestFiles(specName: "auth", asType: AuthTestFile.self)

        for (_, file) in testFiles {
            for testCase in file.tests {
                guard testCase.valid else {
                    expect(try ConnectionString(testCase.uri))
                        .to(throwError(errorType: InvalidArgumentError.self), description: testCase.description)
                    return
                }

                let connString = try ConnectionString(testCase.uri)
                expect(connString.credential).to(equal(testCase.credential), description: testCase.description)
            }
        }
    }
}
