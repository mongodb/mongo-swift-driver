import XCTest
import MongoSwiftTests

var tests = [XCTestCaseEntry]()
tests += MongoSwiftTests.allTests()

XCTMain(tests)
