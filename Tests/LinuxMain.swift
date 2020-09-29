// Generated using Sourcery 0.18.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


@testable import BSONTests
@testable import MongoSwiftTests
@testable import MongoSwiftSyncTests
import XCTest

extension AsyncMongoCursorTests {
    static var allTests = [
        ("testNonTailableCursor", testNonTailableCursor),
        ("testTailableAwaitAsyncCursor", testTailableAwaitAsyncCursor),
        ("testTailableAsyncCursor", testTailableAsyncCursor),
        ("testAsyncNext", testAsyncNext),
        ("testCursorToArray", testCursorToArray),
        ("testForEach", testForEach),
        ("testCursorId", testCursorId),
    ]
}

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

extension BSONPointerUtilsTests {
    static var allTests = [
        ("testWithBSONPointer", testWithBSONPointer),
        ("testBSONPointerInitializer", testBSONPointerInitializer),
    ]
}

extension BSONValueTests {
    static var allTests = [
        ("testInvalidDecimal128", testInvalidDecimal128),
        ("testUUIDBytes", testUUIDBytes),
        ("testBSONEquatable", testBSONEquatable),
        ("testObjectIDRoundTrip", testObjectIDRoundTrip),
        ("testObjectIDJSONCodable", testObjectIDJSONCodable),
        ("testBSONNumber", testBSONNumber),
        ("testBSONBinarySubtype", testBSONBinarySubtype),
    ]
}

extension ChangeStreamSpecTests {
    static var allTests = [
        ("testChangeStreamSpec", testChangeStreamSpec),
    ]
}

extension ChangeStreamTests {
    static var allTests = [
        ("testChangeStreamNext", testChangeStreamNext),
        ("testChangeStreamError", testChangeStreamError),
        ("testChangeStreamEmpty", testChangeStreamEmpty),
        ("testChangeStreamToArray", testChangeStreamToArray),
        ("testChangeStreamForEach", testChangeStreamForEach),
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

extension CommandMonitoringTests {
    static var allTests = [
        ("testCommandMonitoring", testCommandMonitoring),
    ]
}

extension ConnectionStringTests {
    static var allTests = [
        ("testURIOptions", testURIOptions),
        ("testConnectionString", testConnectionString),
        ("testAppNameOption", testAppNameOption),
        ("testReplSetOption", testReplSetOption),
        ("testHeartbeatFrequencyMSOption", testHeartbeatFrequencyMSOption),
        ("testHeartbeatFrequencyMSWithMonitoring", testHeartbeatFrequencyMSWithMonitoring),
        ("testServerSelectionTimeoutMS", testServerSelectionTimeoutMS),
        ("testServerSelectionTimeoutMSWithCommand", testServerSelectionTimeoutMSWithCommand),
        ("testLocalThresholdMSOption", testLocalThresholdMSOption),
        ("testUnsupportedOptions", testUnsupportedOptions),
        ("testCompressionOptions", testCompressionOptions),
        ("testInvalidOptionsCombinations", testInvalidOptionsCombinations),
    ]
}

extension CrudTests {
    static var allTests = [
        ("testReads", testReads),
        ("testWrites", testWrites),
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
        ("testCopyOnWriteBehavior", testCopyOnWriteBehavior),
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
        ("testIndexSubscript", testIndexSubscript),
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

extension LoggingTests {
    static var allTests = [
        ("testCommandLogging", testCommandLogging),
    ]
}

extension MongoClientTests {
    static var allTests = [
        ("testUsingClosedClient", testUsingClosedClient),
        ("testConnectionPoolSize", testConnectionPoolSize),
        ("testListDatabases", testListDatabases),
        ("testClientIdGeneration", testClientIdGeneration),
        ("testResubmittingToThreadPool", testResubmittingToThreadPool),
        ("testConnectionPoolClose", testConnectionPoolClose),
    ]
}

extension MongoCollectionTests {
    static var allTests = [
        ("testCount", testCount),
        ("testInsertOne", testInsertOne),
        ("testInsertOneWithUnacknowledgedWriteConcern", testInsertOneWithUnacknowledgedWriteConcern),
        ("testAggregate", testAggregate),
        ("testGenericAggregate", testGenericAggregate),
        ("testGenericAggregateBadFormat", testGenericAggregateBadFormat),
        ("testDrop", testDrop),
        ("testInsertMany", testInsertMany),
        ("testInsertManyWithEmptyValues", testInsertManyWithEmptyValues),
        ("testInsertManyWithUnacknowledgedWriteConcern", testInsertManyWithUnacknowledgedWriteConcern),
        ("testFind", testFind),
        ("testFindOne", testFindOne),
        ("testFindOneMultipleMatches", testFindOneMultipleMatches),
        ("testFindOneNoMatch", testFindOneNoMatch),
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
        ("testNSNotFoundSuppression", testNSNotFoundSuppression),
        ("testFindOneKillsCursor", testFindOneKillsCursor),
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
        ("testListIndexNames", testListIndexNames),
        ("testCreateDropIndexByModelWithMaxTimeMS", testCreateDropIndexByModelWithMaxTimeMS),
    ]
}

extension MongoCrudV2Tests {
    static var allTests = [
        ("testFindOptionsAllowDiskUse", testFindOptionsAllowDiskUse),
    ]
}

extension MongoCursorTests {
    static var allTests = [
        ("testNonTailableCursor", testNonTailableCursor),
        ("testTailableCursor", testTailableCursor),
        ("testNext", testNext),
        ("testKill", testKill),
        ("testKillTailable", testKillTailable),
        ("testLazySequence", testLazySequence),
        ("testCursorTerminatesOnError", testCursorTerminatesOnError),
        ("testCursorClosedError", testCursorClosedError),
    ]
}

extension MongoDatabaseTests {
    static var allTests = [
        ("testMongoDatabase", testMongoDatabase),
        ("testDropDatabase", testDropDatabase),
        ("testCreateCollection", testCreateCollection),
        ("testListCollections", testListCollections),
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
        ("testRoundTripThroughLibmongoc", testRoundTripThroughLibmongoc),
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
        ("testRoundTripThroughLibmongoc", testRoundTripThroughLibmongoc),
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

extension RetryableReadsTests {
    static var allTests = [
        ("testRetryableReads", testRetryableReads),
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
        ("testInitialReplicaSetDiscovery", testInitialReplicaSetDiscovery),
    ]
}

extension SyncAuthTests {
    static var allTests = [
        ("testAuthProseTests", testAuthProseTests),
    ]
}

extension SyncChangeStreamTests {
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
        ("testChangeStreamLazySequence", testChangeStreamLazySequence),
        ("testDecodingInvalidateEventsOnCollection", testDecodingInvalidateEventsOnCollection),
        ("testDecodingInvalidateEventsOnDatabase", testDecodingInvalidateEventsOnDatabase),
    ]
}

extension SyncClientSessionTests {
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

extension SyncMongoClientTests {
    static var allTests = [
        ("testListDatabases", testListDatabases),
        ("testFailedClientInitialization", testFailedClientInitialization),
        ("testServerVersion", testServerVersion),
        ("testCodingStrategies", testCodingStrategies),
        ("testClientLifetimeManagement", testClientLifetimeManagement),
        ("testAPMCallbacks", testAPMCallbacks),
    ]
}

extension TransactionsTests {
    static var allTests = [
        ("testTransactions", testTransactions),
    ]
}

extension WriteConcernTests {
    static var allTests = [
        ("testWriteConcernType", testWriteConcernType),
        ("testClientWriteConcern", testClientWriteConcern),
        ("testDatabaseWriteConcern", testDatabaseWriteConcern),
        ("testRoundTripThroughLibmongoc", testRoundTripThroughLibmongoc),
    ]
}

XCTMain([
    testCase(AsyncMongoCursorTests.allTests),
    testCase(AuthTests.allTests),
    testCase(BSONCorpusTests.allTests),
    testCase(BSONPointerUtilsTests.allTests),
    testCase(BSONValueTests.allTests),
    testCase(ChangeStreamSpecTests.allTests),
    testCase(ChangeStreamTests.allTests),
    testCase(ClientSessionTests.allTests),
    testCase(CodecTests.allTests),
    testCase(CommandMonitoringTests.allTests),
    testCase(ConnectionStringTests.allTests),
    testCase(CrudTests.allTests),
    testCase(DNSSeedlistTests.allTests),
    testCase(DocumentTests.allTests),
    testCase(Document_CollectionTests.allTests),
    testCase(Document_SequenceTests.allTests),
    testCase(LoggingTests.allTests),
    testCase(MongoClientTests.allTests),
    testCase(MongoCollectionTests.allTests),
    testCase(MongoCollection_BulkWriteTests.allTests),
    testCase(MongoCollection_IndexTests.allTests),
    testCase(MongoCrudV2Tests.allTests),
    testCase(MongoCursorTests.allTests),
    testCase(MongoDatabaseTests.allTests),
    testCase(OptionsTests.allTests),
    testCase(ReadConcernTests.allTests),
    testCase(ReadPreferenceOperationTests.allTests),
    testCase(ReadPreferenceTests.allTests),
    testCase(ReadWriteConcernOperationTests.allTests),
    testCase(ReadWriteConcernSpecTests.allTests),
    testCase(RetryableReadsTests.allTests),
    testCase(RetryableWritesTests.allTests),
    testCase(SDAMTests.allTests),
    testCase(SyncAuthTests.allTests),
    testCase(SyncChangeStreamTests.allTests),
    testCase(SyncClientSessionTests.allTests),
    testCase(SyncMongoClientTests.allTests),
    testCase(TransactionsTests.allTests),
    testCase(WriteConcernTests.allTests),
])
