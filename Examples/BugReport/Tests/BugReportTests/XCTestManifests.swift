import XCTest

#if !os(macOS)
// swiftlint:disable missing_docs
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BugReportTests.allTests)
    ]
}
// swiftlint:enable missing_docs
#endif
