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

extension ReadWriteConcernSpecTests {
    static var allTests = [
        ("testConnectionStrings", testConnectionStrings),
        ("testDocuments", testDocuments),
    ]
}

extension SyncAuthTests {
    static var allTests = [
        ("testAuthProseTests", testAuthProseTests),
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
    testCase(CodecTests.allTests),
    testCase(DNSSeedlistTests.allTests),
    testCase(DocumentTests.allTests),
    testCase(Document_CollectionTests.allTests),
    testCase(Document_SequenceTests.allTests),
    testCase(MongoClientTests.allTests),
    testCase(OptionsTests.allTests),
    testCase(ReadConcernTests.allTests),
    testCase(ReadPreferenceTests.allTests),
    testCase(ReadWriteConcernSpecTests.allTests),
    testCase(SyncAuthTests.allTests),
    testCase(WriteConcernTests.allTests),
])
