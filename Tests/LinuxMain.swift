// Generated using Sourcery 1.3.4 — https://github.com/krzysztofzablocki/Sourcery
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

extension BSONPointerUtilsTests {
    static var allTests = [
        ("testWithBSONPointer", testWithBSONPointer),
        ("testBSONPointerInitializer", testBSONPointerInitializer),
        ("testInitializeBSONObjectIDFromMongoCObjectID", testInitializeBSONObjectIDFromMongoCObjectID),
    ]
}

extension ChangeStreamSpecTests {
    static var allTests = [
        ("testChangeStreamSpec", testChangeStreamSpec),
        ("testChangeStreamSpecUnified", testChangeStreamSpecUnified),
        ("testChangeStreamTruncatedArrays", testChangeStreamTruncatedArrays),
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

extension CommandMonitoringTests {
    static var allTests = [
        ("testCommandMonitoringLegacy", testCommandMonitoringLegacy),
        ("testCommandMonitoringUnified", testCommandMonitoringUnified),
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
        ("testConnectTimeoutMSOption", testConnectTimeoutMSOption),
        ("testUnsupportedOptions", testUnsupportedOptions),
        ("testCompressionOptions", testCompressionOptions),
        ("testInvalidOptionsCombinations", testInvalidOptionsCombinations),
    ]
}

extension CrudTests {
    static var allTests = [
        ("testReads", testReads),
        ("testWrites", testWrites),
        ("testCrudUnified", testCrudUnified),
    ]
}

extension DNSSeedlistTests {
    static var allTests = [
        ("testInitialDNSSeedlistDiscovery", testInitialDNSSeedlistDiscovery),
    ]
}

extension EventLoopBoundMongoClientTests {
    static var allTests = [
        ("testEventLoopBoundDb", testEventLoopBoundDb),
        ("testEventLoopBoundCollection", testEventLoopBoundCollection),
        ("testEventLoopBoundDatabaseChangeStreams", testEventLoopBoundDatabaseChangeStreams),
        ("testEventLoopBoundCollectionChangeStreams", testEventLoopBoundCollectionChangeStreams),
        ("testEventLoopBoundCollectionReads", testEventLoopBoundCollectionReads),
        ("testEventLoopBoundCollectionIndexes", testEventLoopBoundCollectionIndexes),
        ("testEventLoopBoundCollectionFindAndModify", testEventLoopBoundCollectionFindAndModify),
        ("testEventLoopBoundCollectionBulkWrite", testEventLoopBoundCollectionBulkWrite),
        ("testEventLoopBoundSessions", testEventLoopBoundSessions),
        ("testEventLoopBoundWithSession", testEventLoopBoundWithSession),
    ]
}

extension LoadBalancerTests {
    static var allTests = [
        ("testLoadBalancers", testLoadBalancers),
    ]
}

extension MongoClientTests {
    static var allTests = [
        ("testUsingClosedClient", testUsingClosedClient),
        ("testConnectionPoolSize", testConnectionPoolSize),
        ("testListDatabases", testListDatabases),
        ("testClientIdGeneration", testClientIdGeneration),
        ("testBound", testBound),
        ("testResubmittingToThreadPool", testResubmittingToThreadPool),
        ("testConnectionPoolClose", testConnectionPoolClose),
        ("testOCSP", testOCSP),
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
        ("testDeleteOneWithHint", testDeleteOneWithHint),
        ("testDeleteOneWithUnacknowledgedWriteConcern", testDeleteOneWithUnacknowledgedWriteConcern),
        ("testDeleteMany", testDeleteMany),
        ("testDeleteManyWithHint", testDeleteManyWithHint),
        ("testDeleteManyWithUnacknowledgedWriteConcern", testDeleteManyWithUnacknowledgedWriteConcern),
        ("testRenamed", testRenamed),
        ("testRenamedWithDropTarget", testRenamedWithDropTarget),
        ("testReplaceOne", testReplaceOne),
        ("testReplaceOneWithHint", testReplaceOneWithHint),
        ("testReplaceOneWithUnacknowledgedWriteConcern", testReplaceOneWithUnacknowledgedWriteConcern),
        ("testUpdateOne", testUpdateOne),
        ("testUpdateOneWithHint", testUpdateOneWithHint),
        ("testUpdateOneWithUnacknowledgedWriteConcern", testUpdateOneWithUnacknowledgedWriteConcern),
        ("testUpdateMany", testUpdateMany),
        ("testUpdateManyWithHint", testUpdateManyWithHint),
        ("testUpdateManyWithUnacknowledgedWriteConcern", testUpdateManyWithUnacknowledgedWriteConcern),
        ("testUpdateAndReplaceWithHintPreviousVersion", testUpdateAndReplaceWithHintPreviousVersion),
        ("testDistinct", testDistinct),
        ("testGetName", testGetName),
        ("testCursorIteration", testCursorIteration),
        ("testCodableCollection", testCodableCollection),
        ("testCursorType", testCursorType),
        ("testEncodeHint", testEncodeHint),
        ("testFindOneAndDelete", testFindOneAndDelete),
        ("testFindOneAndReplace", testFindOneAndReplace),
        ("testFindOneAndUpdate", testFindOneAndUpdate),
        ("testFindAndModifyWithHintInPreviousVersion", testFindAndModifyWithHintInPreviousVersion),
        ("testFindAndModifyWithHint", testFindAndModifyWithHint),
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
        ("testTextIndex", testTextIndex),
        ("testIndexWithWildCard", testIndexWithWildCard),
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
        ("testAggregate", testAggregate),
        ("testAggregateWithOutputType", testAggregateWithOutputType),
        ("testAggregateWithListLocalSessions", testAggregateWithListLocalSessions),
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
        ("testRetryableWritesLegacy", testRetryableWritesLegacy),
        ("testRetryableWritesUnified", testRetryableWritesUnified),
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
        ("testCertificateVerificationOptions", testCertificateVerificationOptions),
        ("testConnectionTimeout", testConnectionTimeout),
    ]
}

extension TransactionsTests {
    static var allTests = [
        ("testTransactionsLegacy", testTransactionsLegacy),
        ("testTransactionsUnified", testTransactionsUnified),
    ]
}

extension UnifiedRunnerTests {
    static var allTests = [
        ("testSchemaVersion", testSchemaVersion),
        ("testSampleUnifiedTests", testSampleUnifiedTests),
        ("testStrictDecodableTypes", testStrictDecodableTypes),
        ("testServerParameterRequirements", testServerParameterRequirements),
    ]
}

extension VersionedAPITests {
    static var allTests = [
        ("testVersionedAPI", testVersionedAPI),
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
    testCase(BSONPointerUtilsTests.allTests),
    testCase(ChangeStreamSpecTests.allTests),
    testCase(ChangeStreamTests.allTests),
    testCase(ClientSessionTests.allTests),
    testCase(CommandMonitoringTests.allTests),
    testCase(ConnectionStringTests.allTests),
    testCase(CrudTests.allTests),
    testCase(DNSSeedlistTests.allTests),
    testCase(EventLoopBoundMongoClientTests.allTests),
    testCase(LoadBalancerTests.allTests),
    testCase(MongoClientTests.allTests),
    testCase(MongoCollectionTests.allTests),
    testCase(MongoCollection_BulkWriteTests.allTests),
    testCase(MongoCollection_IndexTests.allTests),
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
    testCase(UnifiedRunnerTests.allTests),
    testCase(VersionedAPITests.allTests),
    testCase(WriteConcernTests.allTests),
])
