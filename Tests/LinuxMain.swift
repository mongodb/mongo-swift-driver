import MongoSwift
import MongoSwiftTests
import XCTest

/* Ensure libmongoc is initialized. Since XCTMain never returns, we have no
 * opportunity to cleanup libmongoc (either explicitly or with a deinit). This
 * may appear as a memory leak. */
MongoSwift.initialize()

var tests = [XCTestCaseEntry]()
tests += MongoSwiftTests.allTests()

XCTMain(tests)
