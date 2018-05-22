import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ClientTests.allTests),
        testCase(CodecTests.allTests),
        testCase(CollectionTests.allTests),
        testCase(CommandMonitoringTests.allTests),
        testCase(CrudTests.allTests),
        testCase(DatabaseTests.allTests),
        testCase(DocumentTests.allTests),
        testCase(ReadWriteConcernTests.allTests),
        testCase(SDAMTests.allTests),
    ]
}
#endif