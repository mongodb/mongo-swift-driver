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
}
