import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

/// Represents a single file containing auth tests.
private struct AuthTestFile: Decodable {
    let tests: [AuthTestCase]
}

/// Represents a single test case within a file.
private struct AuthTestCase: Decodable {
    /// A string describing the test.
    let description: String
    /// A string containing the URI to be parsed.
    let uri: String
    /// A boolean indicating if the URI should be considered valid.
    let valid: Bool
    /// An authentication credential. If nil, the credential must not be considered configured for the purpose of
    /// deciding if the driver should authenticate to the topology.
    let credential: TestCredential?
}

/// Represents a MongoCredential within a test case. This additional struct is necessary because some tests specify
/// invalid authentication mechanisms, and we need to be able to decode those without throwing an error.
private struct TestCredential: Decodable {
    private let username: String?
    private let password: String?
    private let source: String?
    private let mechanism: String?
    private let mechanismProperties: BSONDocument?

    private enum CodingKeys: String, CodingKey {
        case username, password, source, mechanism, mechanismProperties = "mechanism_properties"
    }

    fileprivate func toMongoCredential() throws -> MongoCredential {
        var mechanism: MongoCredential.Mechanism?
        if let mechanismString = self.mechanism {
            mechanism = try MongoCredential.Mechanism(mechanismString)
        }
        return MongoCredential(
            username: self.username,
            password: self.password,
            source: self.source,
            mechanism: mechanism,
            mechanismProperties: self.mechanismProperties
        )
    }
}

final class AuthTests: MongoSwiftTestCase {
    func testAuthConnectionStrings() throws {
        let testFiles = try retrieveSpecTestFiles(specName: "auth", asType: AuthTestFile.self)

        for (_, file) in testFiles {
            for testCase in file.tests {
                // We don't support MONGODB-CR authentication.
                guard !testCase.description.contains("MONGODB-CR") else {
                    continue
                }

                guard testCase.valid else {
                    expect(try MongoConnectionString(string: testCase.uri))
                        .to(
                            throwError(errorType: MongoError.InvalidArgumentError.self),
                            description: testCase.description
                        )
                    return
                }

                let connString = try MongoConnectionString(string: testCase.uri)
                if let testCredential = testCase.credential {
                    // We've already skipped tests that contain an invalid auth mechanism, so this should never throw.
                    var credential = try testCredential.toMongoCredential()

                    guard var connStringCredential = connString.credential else {
                        XCTFail("Connection string credential should not be nil: \(testCase.description)")
                        return
                    }

                    if credential.mechanismProperties != nil {
                        // Can't guarantee mechanismProperties was decoded from JSON in a particular order,
                        // so we compare it separately without considering order.
                        expect(connStringCredential.mechanismProperties)
                            .to(sortedEqual(credential.mechanismProperties), description: testCase.description)
                        credential.mechanismProperties = nil
                        connStringCredential.mechanismProperties = nil
                    }

                    // this field is only relevant for rebuilding a connection string
                    credential.sourceFromAuthSource = false
                    connStringCredential.sourceFromAuthSource = false

                    // compare rest of non-document options normally
                    expect(connStringCredential).to(equal(credential), description: testCase.description)
                }
            }
        }
    }
}
