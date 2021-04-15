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

extension MongoCredential {
    func matches(testCredential: MongoCredential, description: String) throws {
        var actual = self
        var expected = testCredential

        expect(actual).toNot(beNil(), description: description)

        // Expected test credentials are populated with default values for properties.
        // However, we do not fill those in MongoConnectionString.
        if expected.source == "admin" && actual.source == nil {
            expected.source = nil
        }
        if expected.mechanism == MongoCredential.Mechanism.gssAPI {
            let defProperty: BSONDocument = ["SERVICE_NAME": "mongodb"]
            let defSource = "$external"
            if expected.mechanismProperties == defProperty &&
                actual.mechanismProperties == nil
            {
                expected.mechanismProperties = nil
            }
            if expected.source == defSource && actual.source == nil {
                expected.source = nil
            }
        }

        if expected.mechanismProperties != nil {
            // Can't guarantee mechanismProperties was decoded from JSON in a particular order,
            // so we compare it separately without considering order.
            expect(actual.mechanismProperties)
                .to(sortedEqual(expected.mechanismProperties), description: description)
            expected.mechanismProperties = nil
            actual.mechanismProperties = nil
        }

        // compare rest of non-document options normally
        expect(actual).to(equal(expected), description: description)
    }
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
                if let credential = testCase.credential, let connStringCredential = connString.credential {
                    try connStringCredential.matches(testCredential: credential, description: testCase.description)
                } else {
                    expect(connString.credential).to(beNil(), description: testCase.description)
                    expect(testCase.credential).to(beNil(), description: testCase.description)
                }
            }
        }
    }
}
