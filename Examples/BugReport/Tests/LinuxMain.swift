import XCTest

import BugReportTests

var tests = [XCTestCaseEntry]()
tests += BugReportTests.allTests()
XCTMain(tests)