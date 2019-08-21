// Generated using Sourcery 0.16.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


@testable import MongoSwiftTests
import XCTest

extension BSONValueTests {
    static var allTests = [
        ("testInvalidDecimal128", testInvalidDecimal128),
        ("testUUIDBytes", testUUIDBytes),
        ("testBSONEquals", testBSONEquals),
        ("testObjectIdRoundTrip", testObjectIdRoundTrip),
        ("testHashable", testHashable),
        ("testBSONNumber", testBSONNumber),
    ]
}

extension ChangeStreamSpecTests {
    static var allTests = [
        ("testChangeStreamSpec", testChangeStreamSpec),
    ]
}

extension ChangeStreamTests {
    static var allTests = [
        ("testChangeStreamTracksResumeToken", testChangeStreamTracksResumeToken),
        ("testChangeStreamMissingId", testChangeStreamMissingId),
        ("testChangeStreamAutomaticResume", testChangeStreamAutomaticResume),
        ("testChangeStreamFailedAggregate", testChangeStreamFailedAggregate),
        ("testChangeStreamDoesntResume", testChangeStreamDoesntResume),
        ("testChangeStreamDoesntCloseOnEmptyBatch", testChangeStreamDoesntCloseOnEmptyBatch),
        ("testChangeStreamFailedKillCursors", testChangeStreamFailedKillCursors),
        ("testChangeStreamResumeTokenUpdatesEmptyBatch", testChangeStreamResumeTokenUpdatesEmptyBatch),
        ("testChangeStreamResumeTokenUpdatesNonemptyBatch", testChangeStreamResumeTokenUpdatesNonemptyBatch),
        ("testChangeStreamOnAClient", testChangeStreamOnAClient),
        ("testChangeStreamOnADatabase", testChangeStreamOnADatabase),
        ("testChangeStreamOnACollection", testChangeStreamOnACollection),
        ("testChangeStreamWithPipeline", testChangeStreamWithPipeline),
        ("testChangeStreamResumeToken", testChangeStreamResumeToken),
        ("testChangeStreamWithEventType", testChangeStreamWithEventType),
        ("testChangeStreamWithFullDocumentType", testChangeStreamWithFullDocumentType),
        ("testChangeStreamOnACollectionWithCodableType", testChangeStreamOnACollectionWithCodableType),
    ]
}

extension ClientSessionTests {
    static var allTests = [
        ("testSessionCleanup", testSessionCleanup),
        ("testSessionArguments", testSessionArguments),
        ("testSessionClientValidation", testSessionClientValidation),
        ("testInactiveSession", testInactiveSession),
        ("testSessionCursor", testSessionCursor),
        ("testClusterTime", testClusterTime),
        ("testCausalConsistency", testCausalConsistency),
        ("testCausalConsistencyStandalone", testCausalConsistencyStandalone),
        ("testCausalConsistencyAnyTopology", testCausalConsistencyAnyTopology),
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
        ("testAnyBSONValueIsBSONCodable", testAnyBSONValueIsBSONCodable),
        ("testIncorrectEncodeFunction", testIncorrectEncodeFunction),
        ("testOptionsEncoding", testOptionsEncoding),
    ]
}

extension CommandMonitoringTests {
    static var allTests = [
        ("testCommandMonitoring", testCommandMonitoring),
        ("testAlternateNotificationCenters", testAlternateNotificationCenters),
    ]
}

extension CrudTests {
    static var allTests = [
        ("testReads", testReads),
        ("testWrites", testWrites),
    ]
}

extension DocumentTests {
    static var allTests = [
        ("testDocument", testDocument),
        ("testDocumentDynamicMemberLookup", testDocumentDynamicMemberLookup),
        ("testDocumentFromArray", testDocumentFromArray),
        ("testEquatable", testEquatable),
        ("testRawBSON", testRawBSON),
        ("testValueBehavior", testValueBehavior),
        ("testIntEncodesAsInt32OrInt64", testIntEncodesAsInt32OrInt64),
        ("testBSONCorpus", testBSONCorpus),
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
        ("testIntegerRetrieval", testIntegerRetrieval),
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
        ("testListDatabases", testListDatabases),
        ("testOpaqueInitialization", testOpaqueInitialization),
        ("testFailedClientInitialization", testFailedClientInitialization),
        ("testServerVersion", testServerVersion),
        ("testCodingStrategies", testCodingStrategies),
    ]
}

extension MongoCollectionTests {
    static var allTests = [
        ("testCount", testCount),
        ("testInsertOne", testInsertOne),
        ("testInsertOneWithUnacknowledgedWriteConcern", testInsertOneWithUnacknowledgedWriteConcern),
        ("testAggregate", testAggregate),
        ("testDrop", testDrop),
        ("testInsertMany", testInsertMany),
        ("testInsertManyWithEmptyValues", testInsertManyWithEmptyValues),
        ("testInsertManyWithUnacknowledgedWriteConcern", testInsertManyWithUnacknowledgedWriteConcern),
        ("testFind", testFind),
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
        ("testCursorIteration", testCursorIteration),
        ("testCodableCollection", testCodableCollection),
        ("testCursorType", testCursorType),
        ("testEncodeHint", testEncodeHint),
        ("testFindOneAndDelete", testFindOneAndDelete),
        ("testFindOneAndReplace", testFindOneAndReplace),
        ("testFindOneAndUpdate", testFindOneAndUpdate),
        ("testNullIds", testNullIds),
    ]
}

extension MongoCollection_BulkWriteTests {
    static var allTests = [
        ("testEmptyRequests", testEmptyRequests),
        ("testInserts", testInserts),
        ("testBulkWriteErrors", testBulkWriteErrors),
        ("testUpdates", testUpdates),
        ("testDeletes", testDeletes),
        ("testMixedOrderedOperations", testMixedOrderedOperations),
        ("testUnacknowledgedWriteConcern", testUnacknowledgedWriteConcern),
    ]
}

extension MongoCollection_IndexTests {
    static var allTests = [
        ("testCreateIndexFromModel", testCreateIndexFromModel),
        ("testIndexOptions", testIndexOptions),
        ("testCreateIndexesFromModels", testCreateIndexesFromModels),
        ("testCreateIndexFromKeys", testCreateIndexFromKeys),
        ("testDropIndexByName", testDropIndexByName),
        ("testDropIndexByModel", testDropIndexByModel),
        ("testDropIndexByKeys", testDropIndexByKeys),
        ("testDropAllIndexes", testDropAllIndexes),
        ("testListIndexes", testListIndexes),
        ("testCreateDropIndexByModelWithMaxTimeMS", testCreateDropIndexByModelWithMaxTimeMS),
    ]
}

extension MongoDatabaseTests {
    static var allTests = [
        ("testMongoDatabase", testMongoDatabase),
        ("testDropDatabase", testDropDatabase),
        ("testCreateCollection", testCreateCollection),
    ]
}

extension ReadPreferenceTests {
    static var allTests = [
        ("testMode", testMode),
        ("testTagSets", testTagSets),
        ("testMaxStalenessSeconds", testMaxStalenessSeconds),
        ("testInitFromPointer", testInitFromPointer),
        ("testEquatable", testEquatable),
        ("testOperationReadPreference", testOperationReadPreference),
        ("testClientReadPreference", testClientReadPreference),
        ("testDatabaseReadPreference", testDatabaseReadPreference),
    ]
}

extension ReadWriteConcernTests {
    static var allTests = [
        ("testReadConcernType", testReadConcernType),
        ("testWriteConcernType", testWriteConcernType),
        ("testClientReadConcern", testClientReadConcern),
        ("testClientWriteConcern", testClientWriteConcern),
        ("testDatabaseReadConcern", testDatabaseReadConcern),
        ("testDatabaseWriteConcern", testDatabaseWriteConcern),
        ("testOperationReadConcerns", testOperationReadConcerns),
        ("testWriteConcernErrors", testWriteConcernErrors),
        ("testOperationWriteConcerns", testOperationWriteConcerns),
        ("testConnectionStrings", testConnectionStrings),
        ("testDocuments", testDocuments),
    ]
}

extension RetryableWritesTests {
    static var allTests = [
        ("testRetryableWrites", testRetryableWrites),
    ]
}

extension SDAMTests {
    static var allTests = [
        ("testMonitoring", testMonitoring),
    ]
}

XCTMain([
    testCase(BSONValueTests.allTests),
    testCase(ChangeStreamSpecTests.allTests),
    testCase(ChangeStreamTests.allTests),
    testCase(ClientSessionTests.allTests),
    testCase(CodecTests.allTests),
    testCase(CommandMonitoringTests.allTests),
    testCase(CrudTests.allTests),
    testCase(DocumentTests.allTests),
    testCase(Document_CollectionTests.allTests),
    testCase(Document_SequenceTests.allTests),
    testCase(MongoClientTests.allTests),
    testCase(MongoCollectionTests.allTests),
    testCase(MongoCollection_BulkWriteTests.allTests),
    testCase(MongoCollection_IndexTests.allTests),
    testCase(MongoDatabaseTests.allTests),
    testCase(ReadPreferenceTests.allTests),
    testCase(ReadWriteConcernTests.allTests),
    testCase(RetryableWritesTests.allTests),
    testCase(SDAMTests.allTests),
])
