import XCTest
import MongoSwiftTests

var tests = [XCTestCaseEntry]()
tests += ClientTests.allTests()
tests += CodecTests.allTests()
tests += CollectionTests.allTests()
tests += CommandMonitoringTests.allTests()
tests += CrudTests.allTests()
tests += DatabaseTests.allTests()
tests += DocumentTests.allTests()
tests += ReadWriteConcernTests.allTests()
tests += SDAMMonitoringTests.allTests()

XCTMain(tests)