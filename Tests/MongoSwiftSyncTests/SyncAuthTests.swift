import Foundation
@testable import MongoSwift
import MongoSwiftSync
import Nimble
import TestsCommon

/// Represents a test user to create and test authenticating with.
struct TestUser {
    let username: String
    let password: String
    let mechanisms: [MongoSwift.MongoCredential.Mechanism]

    /// A command to create this user.
    var createCmd: Document {
        [
            "createUser": .string(self.username),
            "pwd": .string(self.password),
            "roles": ["root"],
            "mechanisms": .array(self.mechanisms.map { .string($0.name) })
        ]
    }

    func createCredential(
        authSource: String = "admin",
        mechanism: MongoCredential.Mechanism? = nil,
        mechanismProperties: Document? = nil
    ) -> MongoCredential {
        MongoCredential(
            username: self.username,
            password: self.password,
            source: authSource,
            mechanism: mechanism,
            mechanismProperties: mechanismProperties
        )
    }

    /// Adds this user's username and password, and an optionally provided auth mechanism, to the connection string.
    func addToConnString(_ connStr: String, mechanism: MongoCredential.Mechanism? = nil) throws -> String {
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
        // if the connection string already has a username, remove the portion up through the @ sign to get what should
        // come after the username.
        let afterUsername = MongoSwiftTestCase.auth ? connStr.drop { $0 != "@" }.dropFirst() : connStr[splitIdx...]

        let joined = "\(connStr[..<splitIdx])\(self.username):\(self.password)@\(afterUsername)"
        guard let mech = mechanism else {
            return joined
        }

        // assume there are already URL parameters if there's a ?, e.g. mongodb://...../?replset=replset0
        if connStr.contains("?") {
            return "\(joined)&authMechanism=\(mech.name)"
        }
        // assume it is a URI that ends with a / and has no params, e.g. mongodb://localhost:27017/
        else if connStr.hasSuffix("/") {
            return "\(joined)?authMechanism=\(mech.name)"
        }
        // assume the URI does not end with a / and also has no params, e.g. mongodb://localhost:27017
        return "\(joined)/?authMechanism=\(mech.name)"
    }
}

final class SyncAuthTests: MongoSwiftTestCase {
    // TODO: SWIFT-640: spec says "Drivers that allow specifying auth parameters in code as well as via connection
    // string should test both for the test cases described below". Once we support setting auth options via options
    // struct we should test that here too.
    func testAuthProseTests() throws {
        let client = try MongoClient.makeTestClient()
        guard try client.serverVersion() >= ServerVersion(major: 4, minor: 0) else {
            print(unsupportedServerVersionMessage(testName: self.name))
            return
        }

        // 1. Create three test users, one with only SHA-1, one with only SHA-256 and one with both.
        let testUsers = [
            TestUser(username: "sha1", password: "sha1", mechanisms: [.scramSHA1]),
            TestUser(username: "sha256", password: "sha256", mechanisms: [.scramSHA256]),
            TestUser(username: "both", password: "both", mechanisms: [.scramSHA1, .scramSHA256])
        ]

        let admin = client.db("admin")
        defer {
            for user in testUsers {
                _ = try? admin.runCommand(["dropUser": .string(user.username)])
            }
        }
        for user in testUsers {
            try admin.runCommand(user.createCmd)
        }

        // 2. For each test user, verify that you can connect and run a command requiring authentication for the
        //    following cases:
        let connString = MongoSwiftTestCase.getConnectionString()
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
                let wrongMech: MongoCredential.Mechanism = user.mechanisms[0] == .scramSHA1 ? .scramSHA256 : .scramSHA1
                let connStrWrongMech = try user.addToConnString(connString, mechanism: wrongMech)
                let clientWrongMech = try MongoClient.makeTestClient(connStrWrongMech)
                expect(try clientWrongMech.db("admin").runCommand(["dbstats": 1]))
                    .to(throwError(errorType: AuthenticationError.self))
            }
        }

        // 2. (again) For each test user, verify that you can connect by specifying credentials in MongoMongoClientOptions
        //    following cases:
        for user in testUsers {
            // - Explicitly specifying each mechanism the user supports.
            try user.mechanisms.forEach { mech in
                let options = MongoClientOptions(credential: user.createCredential(mechanism: mech))
                let client = try MongoClient.makeTestClient(connString, options: options)
                expect(try client.db("admin").runCommand(["dbstats": 1])).toNot(throwError())
            }

            // - Specifying no mechanism and relying on mechanism negotiation.
            let options = MongoClientOptions(credential: user.createCredential())
            let clientNoMech = try MongoClient.makeTestClient(connString, options: options)
            expect(try clientNoMech.db("admin").runCommand(["dbstats": 1])).toNot(throwError())

            // 3. For test users that support only one mechanism, verify that explicitly specifying the other mechanism
            //    fails.
            if user.mechanisms.count == 1 {
                let wrongMech: MongoCredential.Mechanism = user.mechanisms[0] == .scramSHA1 ? .scramSHA256 : .scramSHA1
                let options = MongoClientOptions(credential: user.createCredential(mechanism: wrongMech))
                let clientWrongMech = try MongoClient.makeTestClient(connString, options: options)
                expect(try clientWrongMech.db("admin").runCommand(["dbstats": 1]))
                    .to(throwError(errorType: AuthenticationError.self))
            }
        }

        // 4. To test SASLprep behavior, create two users:
        let saslPrepUsers = [
            TestUser(username: "IX", password: "IX", mechanisms: [.scramSHA256]),
            TestUser(username: "\u{2168}", password: "\u{2163}", mechanisms: [.scramSHA256])
        ]
        defer {
            for user in saslPrepUsers {
                _ = try? admin.runCommand(["dropUser": .string(user.username)])
            }
        }
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
            // TODO: SWIFT-638 : unskip these tests. URIs cannot be parsed by libmongoc - see CDRIVER-3390.
            // TestUser(username: "IX", password: "I%C2%ADX", mechanisms: [.scramSHA256]),
            // TestUser(username: "%E2%85%A8", password: "IV", mechanisms: [.scramSHA256]),
            // TestUser(username: "%E2%85%A8", password: "I%C2%ADV", mechanisms: [.scramSHA256])
        ]

        for user in saslPrepConnectUsers {
            let connStr = try user.addToConnString(connString, mechanism: user.mechanisms[0])
            let client = try MongoClient.makeTestClient(connStr)
            expect(try client.db("admin").runCommand(["dbstats": 1])).toNot(throwError())
        }

        // TODO: whenever auth is implemented in pure Swift - implement this test case:
        // For SCRAM-SHA-1 and SCRAM-SHA-256, test that the minimum iteration count is respected. This may be done via
        // unit testing of an underlying SCRAM library.
    }
}
