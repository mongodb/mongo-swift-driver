import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon

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
    let credential: MongoCredential?
}

final class AuthTests: MongoSwiftTestCase {
    func testAuthConnectionStrings() throws {
        let testFiles = try retrieveSpecTestFiles(specName: "auth", asType: AuthTestFile.self)

        for (_, file) in testFiles {
            for testCase in file.tests {
                guard testCase.valid else {
                    expect(try MongoConnectionString(throwsIfInvalid: testCase.uri))
                        .to(
                            throwError(errorType: MongoError.InvalidArgumentError.self),
                            description: testCase.description
                        )
                    return
                }

                let connString = try MongoConnectionString(throwsIfInvalid: testCase.uri)
                if var credential = testCase.credential, var connStringCredential = connString.credential {
                    expect(connStringCredential).toNot(beNil(), description: testCase.description)

                    // Ignore default properties for now.
                    if credential.source == "admin" && connStringCredential.source == nil {
                        credential.source = nil
                    }
                    if credential.mechanism == MongoCredential.Mechanism.gssAPI {
                        let defProperty: BSONDocument = ["SERVICE_NAME": "mongodb"]
                        let defSource = "$external"
                        if credential.mechanismProperties == defProperty &&
                            connStringCredential.mechanismProperties == nil
                        {
                            credential.mechanismProperties = nil
                        }
                        if credential.source == defSource && connStringCredential.source == nil {
                            credential.source = nil
                        }
                    }

                    if credential.mechanismProperties != nil {
                        // Can't guarantee mechanismProperties was decoded from JSON in a particular order,
                        // so we compare it separately without considering order.
                        expect(connStringCredential.mechanismProperties)
                            .to(sortedEqual(credential.mechanismProperties), description: testCase.description)
                        credential.mechanismProperties = nil
                        connStringCredential.mechanismProperties = nil
                    }

                    // compare rest of non-document options normally
                    expect(connStringCredential).to(equal(credential), description: testCase.description)
                }
            }
        }
    }
}
