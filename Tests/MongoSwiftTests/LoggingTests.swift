import Foundation
@testable import MongoSwift
import Nimble
import TestsCommon

final class LoggingTests: MongoSwiftTestCase {
    func testCommandLogging() throws {
        try self.withTestNamespace { _, db, _ in
            // successful command
            try db.runCommand(["isMaster": 1]).wait()
        }
    }

    func testAuthConnectionStrings() throws {
        let testFiles = try retrieveSpecTestFiles(specName: "auth", asType: AuthTestFile.self)

        for (_, file) in testFiles {
            for testCase in file.tests {
                guard testCase.valid else {
                    expect(try ConnectionString(testCase.uri))
                        .to(
                            throwError(errorType: MongoError.InvalidArgumentError.self),
                            description: testCase.description
                        )
                    return
                }

                let connString = try ConnectionString(testCase.uri)
                expect(connString.credential).to(equal(testCase.credential), description: testCase.description)
            }
        }
    }
}
