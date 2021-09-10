import Foundation
import TestsCommon

final class LeakCheckTests: MongoSwiftTestCase {
    func testLeaks() throws {
        guard let checkForLeaks = ProcessInfo.processInfo.environment["CHECK_LEAKS"], checkForLeaks == "leaks" else {
            return
        }

        // taken from https://forums.swift.org/t/test-for-memory-leaks-in-ci/36526/19
        atexit {
            @discardableResult
            func leaksTo(_ file: String) -> Process {
                let out = FileHandle(forWritingAtPath: file)!
                defer {
                    try! out.close()
                }
                let p = Process()
                p.launchPath = "/usr/bin/leaks"
                p.arguments = ["\(getpid())"]
                p.standardOutput = out
                p.standardError = out
                p.launch()
                p.waitUntilExit()
                return p
            }
            let p = leaksTo("/dev/null")
            print("================")
            guard p.terminationReason == .exit && [0, 1].contains(p.terminationStatus) else {
                print("Leak checking process exited unexpectedly - reason: \(p.terminationReason), status: \(p.terminationStatus)")
                exit(255)
            }
            if p.terminationStatus == 1 {
                print("Unexpectedly leaked memory")
                leaksTo("/dev/tty")
            } else {
                print("No memory leaks!")
            }
            exit(p.terminationStatus)
        }
    }
}
