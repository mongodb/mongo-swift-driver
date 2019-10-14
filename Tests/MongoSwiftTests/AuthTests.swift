import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

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
                guard let str = value as? String else {
                    return value
                }
                switch str {
                case "true":
                    return true
                case "false":
                    return false
                default:
                    return str
                }
            }
        }
    }

    /// Returns the credential configured on this URI. Will be empty if no options are set.
    fileprivate var credential: Credential {
        return Credential(username: self.username,
                          password: self.password,
                          source: self.authSource,
                          mechanism: self.authMechanism,
                          mechanismProperties: self.authMechanismProperties)
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

/// Possible authentication mechanisms.
enum AuthMechanism: String, Decodable {
    case scramSHA1 = "SCRAM-SHA-1"
    case scramSHA256 = "SCRAM-SHA-256"
    case gssAPI = "GSSAPI"
    case mongodbCR = "MONGODB-CR"
    case mongodbX509 = "MONGODB-X509"
    case plain = "PLAIN"
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

    // TODO SWIFT-636: remove this initializer and the one below it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.password = try container.decodeIfPresent(String.self, forKey: .password)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.mechanism = try container.decodeIfPresent(AuthMechanism.self, forKey: .mechanism)

        // libmongoc does not return the service name if it's the default, but it is contained in the spec test files,
        // so filter it out here if it's present.
        let properties = try container.decodeIfPresent(Document.self, forKey: .mechanismProperties)
        let filteredProperties = properties?.filter { !($0.0 == "SERVICE_NAME" && $0.1 as? String == "mongodb") }
        // if SERVICE_NAME was the only key then don't return an empty document.
        if filteredProperties?.isEmpty == true {
            self.mechanismProperties = nil
        } else {
            self.mechanismProperties = filteredProperties
        }
    }

    init(username: String?, password: String?, source: String?, mechanism: AuthMechanism?, mechanismProperties: Document?) {
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
        let invalidArgumentError = UserError.invalidArgumentError(message: "")

            for (_, file) in testFiles {
            for testCase in file.tests {
                guard testCase.valid else {
                    expect(try ConnectionString(testCase.uri))
                        .to(throwError(invalidArgumentError), description: testCase.description)
                    return
                }

                let connString = try ConnectionString(testCase.uri)
                expect(connString.credential).to(equal(testCase.credential), description: testCase.description)
            }
        }
    }

    /// Represents a test user to create and test authenticating with.
    struct TestUser {
        let username: String
        let password: String
        let mechanisms: [AuthMechanism]

        /// A command to create this user.
        var createCmd: Document {
            return [
                        "createUser": self.username,
                        "pwd": self.password, "roles": ["root"],
                        "mechanisms": self.mechanisms.map { $0.rawValue }
                    ]
        }

        /// Adds this user's username and password, and an optionally provided auth mechanism, to the connection string.
        func addToConnString(_ connStr: String, mechanism: AuthMechanism? = nil) throws -> String {
            // find where the first / is.
            guard let firstSlash = connStr.firstIndex(of: "/") else {
                throw TestError(message: "expected connection string to contain slash")
            }

            // this should also be a / in a properly formatted URI.
            let nextIdx = connStr.index(after: firstSlash)
            guard connStr[nextIdx] == "/" else {
                throw TestError(message: "expected connection string to contain '//'")
            }

            // we want to split right after the // to insert the username and password.
            let splitIdx = connStr.index(firstSlash, offsetBy: 2)

            let joined = "\(connStr[..<splitIdx])\(self.username):\(self.password)@\(connStr[splitIdx...])"
            guard let mech = mechanism else {
                return joined
            }

            // assume there are already URL parameters if there's a ?, e.g. mongodb://...../?replset=replset0
            if connStr.contains("?") {
                return "\(joined)&authMechanism=\(mech.rawValue)"
            }
            // assume it is a URI that ends with a / and has no params, e.g. mongodb://localhost:27017/
            else if connStr.hasSuffix("/") {
                return "\(joined)?authMechanism=\(mech.rawValue)"
            }
            // assume the URI does not end with a / and also has no params, e.g. mongodb://localhost:27017
            return "\(joined)/?authMechanism=\(mech.rawValue)"
        }
    }

    func testAuthProseTests() throws {
        // 1. Create three test users, one with only SHA-1, one with only SHA-256 and one with both.
        let testUsers = [
            TestUser(username: "sha1", password: "sha1", mechanisms: [.scramSHA1]),
            TestUser(username: "sha256", password: "sha256", mechanisms: [.scramSHA256]),
            TestUser(username: "both", password: "both", mechanisms: [.scramSHA1, .scramSHA256])
        ]

        let admin = try MongoClient.makeTestClient().db("admin")
        defer { _ = try? admin.runCommand(["dropAllUsersFromDatabase": 1]) }
        for user in testUsers {
            try admin.runCommand(user.createCmd)
        }

        // 2. For each test user, verify that you can connect and run a command requiring authentication for the
        //    following cases:
        let connString = MongoSwiftTestCase.connStr
        for user in testUsers {
            // - Explicitly specifying each mechanism the user supports.
            try user.mechanisms.forEach { mech in
                let connStr = try user.addToConnString(connString, mechanism: mech)
                let client = try MongoClient.makeTestClient(connStr)
                expect(try client.db("admin").runCommand(["dbstats": 1])).toNot(throwError())
            }

            // - Specifying no mechanism and relying on mechanism negotiation.
            let connStrNoMech = try user.addToConnString(connString)
            let clientNoMech = try MongoClient.makeTestClient(connStrNoMech)
            expect(try clientNoMech.db("admin").runCommand(["dbstats": 1])).toNot(throwError())

            // 3. For test users that support only one mechanism, verify that explicitly specifying the other mechanism
            //    fails.
            if user.mechanisms.count == 1 {
                let wrongMech: AuthMechanism = user.mechanisms[0] == .scramSHA1 ? .scramSHA256 : .scramSHA1
                let connStrWrongMech = try user.addToConnString(connString, mechanism: wrongMech)
                let clientWrongMech = try MongoClient.makeTestClient(connStrWrongMech)
                expect(try clientWrongMech.db("admin").runCommand(["dbstats": 1]))
                    .to(throwError(RuntimeError.authenticationError(message: "")))
            }
        }

        // 4. To test SASLprep behavior, create two users:
        let saslPrepUsers = [
            TestUser(username: "IX", password: "IX", mechanisms: [.scramSHA256]),
            TestUser(username: "\\u2168", password: "\\u2163", mechanisms: [.scramSHA256])
        ]
        for user in saslPrepUsers {
            try admin.runCommand(user.createCmd)
        }

        // For each user, verify that the driver can authenticate with the password in both SASLprep normalized and
        // non-normalized forms:
        // - User "IX": use password forms "IX" and "I\\u00ADX"
        // - User "\\u2168": use password forms "IV" and "I\\u00ADV"
        //   As a URI, those have to be UTF-8 encoded and URL-escaped.
        let saslPrepConnectUsers = [
            TestUser(username: "IX", password: "IX", mechanisms: [.scramSHA256])
            // TODO SWIFT-638 : unskip these tests. URIs cannot be parsed by libmongoc - see CDRIVER-3390.
            //TestUser(username: "IX", password: "I%C2%ADX", mechanisms: [.scramSHA256]),
            //TestUser(username: "%E2%85%A8", password: "IV", mechanisms: [.scramSHA256]),
            //TestUser(username: "%E2%85%A8", password: "I%C2%ADV", mechanisms: [.scramSHA256])
        ]

        for user in saslPrepConnectUsers {
            let connStr = try user.addToConnString(connString, mechanism: user.mechanisms[0])
            let client = try MongoClient.makeTestClient(connStr)
            expect(try client.db("admin").runCommand(["dbstats": 1])).toNot(throwError())
        }

        // TODO whenever auth is implemented in pure Swift - implement this test case:
        // For SCRAM-SHA-1 and SCRAM-SHA-256, test that the minimum iteration count is respected. This may be done via
        // unit testing of an underlying SCRAM library.
    }
}
