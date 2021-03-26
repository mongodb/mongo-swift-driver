import Foundation

// swiftlint:disable explicit_acl

/// Represents a test suite.
struct TestSuite {
    /// Name of the test suite.
    let name: String

    /// Total execution time for the test suite, in seconds.
    let time: TimeInterval

    /// Tests in the suite.
    let tests: [TestCase]

    /// Count of tests in the suite.
    let count: Int

    /// Count of failed tests in the suite.
    let failureCount: Int

    /// Converts this test suite to XML.
    func toXML() -> String {
        var output =
            """
            <testsuite tests="\(self.count)" failures="\(self.failureCount)" \
            errors="0" time="\(self.time)" name="\(self.name)">\n
            """

        for test in self.tests {
            output += test.toXML()
        }

        output += "</testsuite>\n"
        return output
    }
}

/// Represents a test case.
struct TestCase {
    /// The name of the class this test case belongs to.
    let className: String

    /// The name of this test case.
    let name: String

    /// The time the test case took to run, in seconds.
    let time: TimeInterval

    /// Failure message produced by the test case, if any.
    let failure: String?

    func toXML() -> String {
        var output =
            """
            <testcase classname="\(self.className)" name="\(self.name)" time="\(self.time)">\n
            """

        if let failure = self.failure {
            // hack to replace disallowed XML characters with very similar unicode ones.
            // evergreen doesn't render the escaped XML characters correctly so this preserves
            // readability while keeping the XML valid.
            let escapedFailure = failure
                .replacingOccurrences(of: "\"", with: "＂")
                .replacingOccurrences(of: "'", with: "＇")
                .replacingOccurrences(of: "<", with: "﹤")
                .replacingOccurrences(of: ">", with: "﹥")
                .replacingOccurrences(of: "&", with: "﹠")

            output +=
                """
                <failure message="\(escapedFailure)"></failure>\n
                """
        }

        output += "</testcase>\n"
        return output
    }
}

// Top-level redundant suites that we don't need to put into the xunit output.
let ignoreSuites = [
    // macOS
    "AllTests",
    "mongo-swift-driverPackageTests.xctest",
    // linux
    "All tests",
    "debug.xctest",
    "Selected tests" // this shows us when --filter is used
]

/// An error thrown while parsing test output.
struct ParsingError: LocalizedError {
    let message: String

    public var errorDescription: String? { self.message }

    init(_ message: String) {
        self.message = message
    }
}

extension NSTextCheckingResult {
    func readMatch(at position: Int, in line: String) throws -> String {
        guard let range = Range(self.range(at: position), in: line) else {
            throw ParsingError("No capture group match at position \(position)")
        }
        return String(line[range])
    }
}

extension TimeInterval {
    init(input: String) throws {
        guard let time = TimeInterval(input) else {
            throw ParsingError("unable to parse TimeInterval from \(input)")
        }
        self = time
    }
}

func ensureSuiteMatches(old: String, new: String) throws {
    guard old == new else {
        throw ParsingError("test suite name \(new) does not match previously found name for current suite \(old)")
    }
}

/// State machine which processes `swift test` output and updates itself accordingly.
enum ParsingState {
    /// In the following cases:
    /// - `completeTests` is stored whenever we are in the middle of a suite, and contains any test cases we have found
    ///   for the suite so far.
    /// - `completeSuites` is always stored and contains all of the suites we have fully parsed so far.

    /// We have read a line indicating that a test suite with the given name started, but we are not in a particular
    /// test case.
    case inSuite(name: String, completeTests: [TestCase], completeSuites: [TestSuite])
    /// We've read a line indicating that a suite with the given name ended, and are expecting to read a next line
    /// containing test pass/fail counts for the suite.
    case awaitingSuiteDetails(name: String, completeTests: [TestCase], completeSuites: [TestSuite])
    /// We are in the middle of a test with the given name in the given suite. `output` contains any output the test
    /// case has produced.
    case inTest(suite: String, name: String, output: [String], completeTests: [TestCase], completeSuites: [TestSuite])
    /// None of the above. This means we are between test suites.
    case none(completeSuites: [TestSuite])

// account for variation in formatting of test output on platforms. this assumes you are running this script on the
// same platform where you ran the tests. disable force_try since we know these are valid regexes.
// swiftlint:disable force_try
#if os(macOS)
    static let testCaseStartedRegex = try! NSRegularExpression(pattern: #"Test Case '-\[.+\.(.+) (.+)\]' started"#)
    static let testCaseStatusRegex = try! NSRegularExpression(
        pattern: #"Test Case '-\[.+\.(.+) (.+)\]' (passed|failed) \((.+) seconds\)"#
    )
#else
    static let testCaseStartedRegex = try! NSRegularExpression(pattern: #"Test Case '(.+)\.(.+)' started"#)
    static let testCaseStatusRegex = try! NSRegularExpression(
        pattern: #"Test Case '(.+)\.(.+)' (passed|failed) \((.+) seconds\)"#
    )
#endif
    static let testSuiteStartedRegex = try! NSRegularExpression(pattern: #"Test Suite '(.+)' started"#)
    static let testSuiteStatusRegex = try! NSRegularExpression(pattern: #"Test Suite '(.+)' (passed|failed)"#)
    static let testSuiteDetailsRegex = try! NSRegularExpression(
        pattern: #"Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\) in (.+) \("#
    )
    // swiftlint:enable force_try

    /// Processes a new line of test output and updates self accordingly.
    mutating func processLine(_ line: String) throws {
        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)

        if let match = Self.testCaseStartedRegex.firstMatch(in: line, range: fullRange) {
            try self.processTestCaseStart(line: line, regexResult: match)
        } else if let match = Self.testCaseStatusRegex.firstMatch(in: line, range: fullRange) {
            try self.processTestCaseStatus(line: line, regexResult: match)
        } else if let match = Self.testSuiteStartedRegex.firstMatch(in: line, range: fullRange) {
            try self.processSuiteStart(line: line, regexResult: match)
        } else if let match = Self.testSuiteStatusRegex.firstMatch(in: line, range: fullRange) {
            try self.processSuiteStatus(line: line, regexResult: match)
        } else if let match = Self.testSuiteDetailsRegex.firstMatch(in: line, range: fullRange) {
            try self.processSuiteDetails(line: line, regexResult: match)
        } else {
            self.processOtherOutput(line)
        }
    }

    /// Processes a line indicating that a suite has started.
    mutating func processSuiteStart(line: String, regexResult: NSTextCheckingResult) throws {
        let name = try String(regexResult.readMatch(at: 1, in: line))
        guard !ignoreSuites.contains(name) else {
            return
        }
        guard case let .none(completeSuites) = self else {
            throw ParsingError("Unexpectedly encountered suite start")
        }

        self = .inSuite(name: name, completeTests: [], completeSuites: completeSuites)
    }

    /// Processes a line indicating that a suite has completed.
    mutating func processSuiteStatus(line: String, regexResult: NSTextCheckingResult) throws {
        let name = try regexResult.readMatch(at: 1, in: line)
        guard !ignoreSuites.contains(name) else {
            return
        }

        guard case let .inSuite(prevSuite, completeTests, completeSuites) = self else {
            throw ParsingError("Unexpectedly encountered test case outside of a suite")
        }

        try ensureSuiteMatches(old: prevSuite, new: name)
        self = .awaitingSuiteDetails(name: name, completeTests: completeTests, completeSuites: completeSuites)
    }

    /// Processes a line containing pass/fail counts for a suite's tests.
    mutating func processSuiteDetails(line: String, regexResult: NSTextCheckingResult) throws {
        guard case .awaitingSuiteDetails(let prevName, let completeTests, var completeSuites) = self else {
            return
        }

        let countStr = try regexResult.readMatch(at: 1, in: line)

        guard let count = Int(countStr) else {
            throw ParsingError("failed to parse integer from string \(countStr)")
        }
        guard count == completeTests.count else {
            throw ParsingError("Suite has \(count) tests, but only \(completeTests.count) were found from output")
        }

        let failuresStr = try regexResult.readMatch(at: 2, in: line)
        guard let failures = Int(failuresStr) else {
            throw ParsingError("failed to parse integer from string \(failuresStr)")
        }

        let foundFailureCount = completeTests.filter { $0.failure != nil }.count
        guard failures == foundFailureCount else {
            throw ParsingError("Suite has \(failures) failures, but only \(foundFailureCount) were found from output")
        }

        let timeStr = try regexResult.readMatch(at: 3, in: line)
        let time = try TimeInterval(input: timeStr)

        let newSuite = TestSuite(
            name: prevName,
            time: time,
            tests: completeTests,
            count: count,
            failureCount: failures
        )

        completeSuites.append(newSuite)
        self = .none(completeSuites: completeSuites)
    }

    /// Processes a line indicating the start of a test case.
    mutating func processTestCaseStart(line: String, regexResult: NSTextCheckingResult) throws {
        guard case let .inSuite(prevSuite, completeTests, completeSuites) = self else {
            throw ParsingError("Unexpectedly encountered test case outside of a suite")
        }

        let suiteName = try regexResult.readMatch(at: 1, in: line)
        try ensureSuiteMatches(old: prevSuite, new: suiteName)

        let testName = try regexResult.readMatch(at: 2, in: line)
        self = .inTest(
            suite: suiteName,
            name: testName,
            output: [],
            completeTests: completeTests,
            completeSuites: completeSuites
        )
    }

    /// Processes a line indicating the pass/fail status of a test case.
    mutating func processTestCaseStatus(line: String, regexResult: NSTextCheckingResult) throws {
        guard case .inTest(let prevSuite, let prevName, let output, var completeTests, let completeSuites) = self else {
            throw ParsingError("unexpected encountered test case status outside of test case")
        }

        let suiteName = try regexResult.readMatch(at: 1, in: line)
        try ensureSuiteMatches(old: prevSuite, new: suiteName)

        let testName = try regexResult.readMatch(at: 2, in: line)
        guard testName == prevName else {
            throw ParsingError(
                "test name \(testName) does not match previously found name for current test \(testName)"
            )
        }

        let status = try regexResult.readMatch(at: 3, in: line)

        var failureOutput: String?
        switch status {
        case "passed":
            break
        case "failed":
            failureOutput = output.joined(separator: "\n")
        default:
            throw ParsingError("Unrecognized test status \(status)")
        }

        let timeStr = try regexResult.readMatch(at: 4, in: line)
        let time = try TimeInterval(input: timeStr)

        let newTestCase = TestCase(
            className: suiteName,
            name: testName,
            time: time,
            failure: failureOutput
        )

        completeTests.append(newTestCase)
        self = .inSuite(name: suiteName, completeTests: completeTests, completeSuites: completeSuites)
    }

    /// Processes any output line that didn't fall into the above categories e.g. print statements within tests.
    mutating func processOtherOutput(_ line: String) {
        if case .inTest(let suite, let name, var output, let completeTests, let completeSuites) = self {
            output.append(line)
            self = .inTest(
                suite: suite,
                name: name,
                output: output,
                completeTests: completeTests,
                completeSuites: completeSuites
            )
        }
    }
}

var state: ParsingState = .none(completeSuites: [])

while let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
    try state.processLine(line)
}

guard case let .none(completeSuites) = state else {
    throw ParsingError("Ended in unexpected state \(state)")
}

let fullXML =
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuites>
    """
    + completeSuites.map { $0.toXML() }.reduce("", +)
    + "</testsuites>"

print(fullXML)
