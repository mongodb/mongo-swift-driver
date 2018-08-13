import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BsonValueTests.allTests),
        testCase(CodecTests.allTests),
        testCase(CommandMonitoringTests.allTests),
        testCase(CrudTests.allTests),
        testCase(MongoClientTests.allTests),
        testCase(MongoCollectionTests.allTests),
        testCase(MongoDatabaseTests.allTests),
        testCase(DocumentTests.allTests),
        testCase(ReadPreferenceTests.allTests),
        testCase(ReadWriteConcernTests.allTests),
        testCase(SDAMTests.allTests)
    ]
}
#endif
