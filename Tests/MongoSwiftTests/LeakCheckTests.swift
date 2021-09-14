import Foundation
import TestsCommon

final class LeakCheckTests: MongoSwiftTestCase {
    func testLeaks() throws {
        guard let checkForLeaks = ProcessInfo.processInfo.environment["CHECK_LEAKS"], checkForLeaks == "leaks" else {
            return
        }

        // inspired by https://forums.swift.org/t/test-for-memory-leaks-in-ci/36526/19
        atexit {
            func leaks() -> Process {
                let p = Process()
                p.launchPath = "/usr/bin/leaks"
                p.arguments = ["\(getpid())"]
                p.launch()
                p.waitUntilExit()
                return p
            }
            let p = leaks()
            print("================")
            guard p.terminationReason == .exit && [0, 1].contains(p.terminationStatus) else {
                print("Leak checking process exited unexpectedly - " +
                    "reason: \(p.terminationReason), status: \(p.terminationStatus)")
                exit(255)
            }
            if p.terminationStatus == 1 {
                print("Unexpectedly leaked memory")
            } else {
                print("No memory leaks!")
            }
            exit(p.terminationStatus)
        }
    }
}
