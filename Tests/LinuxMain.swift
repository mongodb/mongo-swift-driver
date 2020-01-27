// Generated using Sourcery 0.16.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


@testable import BSONTests
@testable import MongoSwiftTests
@testable import MongoSwiftSyncTests
import XCTest

extension AuthTests {
    static var allTests = [
        ("testAuthConnectionStrings", testAuthConnectionStrings),
    ]
}

extension BSONCorpusTests {
    static var allTests = [
        ("testBSONCorpus", testBSONCorpus),
    ]
}

extension BSONValueTests {
    static var allTests = [
        ("testInvalidDecimal128", testInvalidDecimal128),
        ("testUUIDBytes", testUUIDBytes),
        ("testBSONEquatable", testBSONEquatable),
        ("testObjectIdRoundTrip", testObjectIdRoundTrip),
        ("testBSONNumber", testBSONNumber),
    ]
}

extension ClientSessionTests {
    static var allTests = [
        ("testSession", testSession),
        ("testWithSession", testWithSession),
    ]
}

extension CodecTests {
    static var allTests = [
        ("testStructs", testStructs),
        ("testOptionals", testOptionals),
        ("testEncodingNonBSONNumbers", testEncodingNonBSONNumbers),
        ("testDecodingNonBSONNumbers", testDecodingNonBSONNumbers),
        ("testBSONNumbers", testBSONNumbers),
        ("testBSONValues", testBSONValues),
        ("testDecodeScalars", testDecodeScalars),
        ("testDocumentIsCodable", testDocumentIsCodable),
        ("testEncodeArray", testEncodeArray),
        ("testBSONIsBSONCodable", testBSONIsBSONCodable),
        ("testIncorrectEncodeFunction", testIncorrectEncodeFunction),
        ("testOptionsEncoding", testOptionsEncoding),
    ]
}

extension DNSSeedlistTests {
    static var allTests = [
        ("testInitialDNSSeedlistDiscovery", testInitialDNSSeedlistDiscovery),
    ]
}

extension DocumentTests {
    static var allTests = [
        ("testDocument", testDocument),
        ("testDocumentDynamicMemberLookup", testDocumentDynamicMemberLookup),
        ("testEquatable", testEquatable),
        ("testRawBSON", testRawBSON),
        ("testValueBehavior", testValueBehavior),
        ("testIntEncodesAsInt32OrInt64", testIntEncodesAsInt32OrInt64),
        ("testMerge", testMerge),
        ("testNilInNestedArray", testNilInNestedArray),
        ("testOverwritable", testOverwritable),
        ("testNonOverwritable", testNonOverwritable),
        ("testReplaceValueWithNewType", testReplaceValueWithNewType),
        ("testReplaceValueWithNil", testReplaceValueWithNil),
        ("testReplaceValueNoop", testReplaceValueNoop),
        ("testDocumentDictionarySimilarity", testDocumentDictionarySimilarity),
        ("testDefaultSubscript", testDefaultSubscript),
        ("testMultibyteCharacterStrings", testMultibyteCharacterStrings),
        ("testUUIDEncodingStrategies", testUUIDEncodingStrategies),
        ("testUUIDDecodingStrategies", testUUIDDecodingStrategies),
        ("testDateEncodingStrategies", testDateEncodingStrategies),
        ("testDateDecodingStrategies", testDateDecodingStrategies),
        ("testDataCodingStrategies", testDataCodingStrategies),
        ("testIntegerLiteral", testIntegerLiteral),
        ("testInvalidBSON", testInvalidBSON),
    ]
}

extension Document_CollectionTests {
    static var allTests = [
        ("testIndexLogic", testIndexLogic),
        ("testMutators", testMutators),
        ("testPrefixSuffix", testPrefixSuffix),
    ]
}

extension Document_SequenceTests {
    static var allTests = [
        ("testIterator", testIterator),
        ("testMapFilter", testMapFilter),
        ("testDropFirst", testDropFirst),
        ("testDropLast", testDropLast),
        ("testDropPredicate", testDropPredicate),
        ("testPrefixLength", testPrefixLength),
        ("testPrefixPredicate", testPrefixPredicate),
        ("testSuffix", testSuffix),
        ("testSplit", testSplit),
        ("testIsEmpty", testIsEmpty),
    ]
}

extension MongoClientTests {
    static var allTests = [
        ("testUsingClosedClient", testUsingClosedClient),
        ("testListDatabases", testListDatabases),
        ("testClientIdGeneration", testClientIdGeneration),
    ]
}

extension MongoCollectionTests {
    static var allTests = [
        ("testCount", testCount),
        ("testInsertOne", testInsertOne),
        ("testInsertOneWithUnacknowledgedWriteConcern", testInsertOneWithUnacknowledgedWriteConcern),
        ("testDrop", testDrop),
        ("testInsertMany", testInsertMany),
        ("testInsertManyWithEmptyValues", testInsertManyWithEmptyValues),
        ("testInsertManyWithUnacknowledgedWriteConcern", testInsertManyWithUnacknowledgedWriteConcern),
        ("testDeleteOne", testDeleteOne),
        ("testDeleteOneWithUnacknowledgedWriteConcern", testDeleteOneWithUnacknowledgedWriteConcern),
        ("testDeleteMany", testDeleteMany),
        ("testDeleteManyWithUnacknowledgedWriteConcern", testDeleteManyWithUnacknowledgedWriteConcern),
        ("testReplaceOne", testReplaceOne),
        ("testReplaceOneWithUnacknowledgedWriteConcern", testReplaceOneWithUnacknowledgedWriteConcern),
        ("testUpdateOne", testUpdateOne),
        ("testUpdateOneWithUnacknowledgedWriteConcern", testUpdateOneWithUnacknowledgedWriteConcern),
        ("testUpdateMany", testUpdateMany),
        ("testUpdateManyWithUnacknowledgedWriteConcern", testUpdateManyWithUnacknowledgedWriteConcern),
        ("testDistinct", testDistinct),
        ("testGetName", testGetName),
        ("testCodableCollection", testCodableCollection),
        ("testCursorType", testCursorType),
        ("testEncodeHint", testEncodeHint),
        ("testFindOneAndDelete", testFindOneAndDelete),
        ("testFindOneAndReplace", testFindOneAndReplace),
        ("testFindOneAndUpdate", testFindOneAndUpdate),
        ("testNullIds", testNullIds),
    ]
}

extension OptionsTests {
    static var allTests = [
        ("testOptionsAlphabeticalOrder", testOptionsAlphabeticalOrder),
    ]
}

extension ReadConcernTests {
    static var allTests = [
        ("testReadConcernType", testReadConcernType),
        ("testClientReadConcern", testClientReadConcern),
        ("testDatabaseReadConcern", testDatabaseReadConcern),
    ]
}

extension ReadPreferenceOperationTests {
    static var allTests = [
        ("testOperationReadPreference", testOperationReadPreference),
    ]
}

extension ReadPreferenceTests {
    static var allTests = [
        ("testMode", testMode),
        ("testTagSets", testTagSets),
        ("testMaxStalenessSeconds", testMaxStalenessSeconds),
        ("testInitFromPointer", testInitFromPointer),
        ("testEquatable", testEquatable),
        ("testClientReadPreference", testClientReadPreference),
        ("testDatabaseReadPreference", testDatabaseReadPreference),
    ]
}

extension ReadWriteConcernOperationTests {
    static var allTests = [
        ("testOperationReadConcerns", testOperationReadConcerns),
        ("testWriteConcernErrors", testWriteConcernErrors),
        ("testOperationWriteConcerns", testOperationWriteConcerns),
    ]
}

extension ReadWriteConcernSpecTests {
    static var allTests = [
        ("testConnectionStrings", testConnectionStrings),
        ("testDocuments", testDocuments),
    ]
}

extension SDAMTests {
    static var allTests = [
        ("testMonitoring", testMonitoring),
    ]
}

extension SyncAuthTests {
    static var allTests = [
        ("testAuthProseTests", testAuthProseTests),
    ]
}

extension SyncClientSessionTests {
    static var allTests = [
        ("testSessionCleanup", testSessionCleanup),
        ("testSessionArguments", testSessionArguments),
        ("testSessionClientValidation", testSessionClientValidation),
        ("testInactiveSession", testInactiveSession),
        ("testClusterTime", testClusterTime),
        ("testCausalConsistency", testCausalConsistency),
        ("testCausalConsistencyStandalone", testCausalConsistencyStandalone),
        ("testCausalConsistencyAnyTopology", testCausalConsistencyAnyTopology),
    ]
}

extension SyncMongoClientTests {
    static var allTests = [
        ("testListDatabases", testListDatabases),
        ("testFailedClientInitialization", testFailedClientInitialization),
        ("testServerVersion", testServerVersion),
        ("testCodingStrategies", testCodingStrategies),
        ("testClientLifetimeManagement", testClientLifetimeManagement),
    ]
}

extension WriteConcernTests {
    static var allTests = [
        ("testWriteConcernType", testWriteConcernType),
        ("testClientWriteConcern", testClientWriteConcern),
        ("testDatabaseWriteConcern", testDatabaseWriteConcern),
    ]
}

XCTMain([
    testCase(AuthTests.allTests),
    testCase(BSONCorpusTests.allTests),
    testCase(BSONValueTests.allTests),
    testCase(ClientSessionTests.allTests),
    testCase(CodecTests.allTests),
    testCase(DNSSeedlistTests.allTests),
    testCase(DocumentTests.allTests),
    testCase(Document_CollectionTests.allTests),
    testCase(Document_SequenceTests.allTests),
    testCase(MongoClientTests.allTests),
    testCase(MongoCollectionTests.allTests),
    testCase(OptionsTests.allTests),
    testCase(ReadConcernTests.allTests),
    testCase(ReadPreferenceOperationTests.allTests),
    testCase(ReadPreferenceTests.allTests),
    testCase(ReadWriteConcernOperationTests.allTests),
    testCase(ReadWriteConcernSpecTests.allTests),
    testCase(SDAMTests.allTests),
    testCase(SyncAuthTests.allTests),
    testCase(SyncClientSessionTests.allTests),
    testCase(SyncMongoClientTests.allTests),
    testCase(WriteConcernTests.allTests),
])
