#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import TestsCommon

@available(macOS 10.15, *)
final class UnifiedRunnerTests: MongoSwiftTestCase {
    func testSchemaVersion() {
        let oneTwoThree = SchemaVersion(rawValue: "1.2.3")
        expect(oneTwoThree).toNot(beNil())
        expect(oneTwoThree?.major).to(equal(1))
        expect(oneTwoThree?.minor).to(equal(2))
        expect(oneTwoThree?.patch).to(equal(3))

        // no patch provided
        let oneTwo = SchemaVersion(rawValue: "1.2")
        expect(oneTwo).toNot(beNil())
        expect(oneTwo?.major).to(equal(1))
        expect(oneTwo?.minor).to(equal(2))
        expect(oneTwo?.patch).to(equal(0))

        // no minor provided
        let one = SchemaVersion(rawValue: "1")
        expect(one).toNot(beNil())
        expect(one?.major).to(equal(1))
        expect(one?.minor).to(equal(0))
        expect(one?.patch).to(equal(0))

        // invalid inputs
        let inputs = [
            "a",
            "1.2.3.4",
            ""
        ]

        for input in inputs {
            expect(SchemaVersion(rawValue: input)).to(beNil())
        }
    }

    func testSampleUnifiedTests() async throws {
        let skipValidPassFiles = [
            // we don't support convenient txns API.
            "poc-transactions-convenient-api.json",
            // we don't support GridFS.
            "poc-gridfs.json",
            // libmongoc does not support connection monitoring, so neither do we.
            "entity-client-cmap-events.json",
            // libmongoc does not implement CMAP or expose this information to us.
            "assertNumberConnectionsCheckedOut.json",
            // we only support command events, and this file tests the ability to parse
            // expected command events.
            "expectedEventsForClient-eventType.json",
            // we have not implemented this test runner feature yet. TODO: SWIFT-1288
            "observeSensitiveCommands.json",
            // We don't support storeEventsAsEntities yet. TODO: SWIFT-1077
            "entity-client-storeEventsAsEntities.json"
        ]

        let validPassTests = try retrieveSpecTestFiles(
            specName: "unified-test-format",
            subdirectory: "valid-pass",
            excludeFiles: skipValidPassFiles,
            asType: UnifiedTestFile.self
        ).map { $0.1 }

        let runner = try await UnifiedTestRunner()
        try await runner.runFiles(validPassTests)

        // These are test files that we cannot/should not be able to decode because they operations they contain are
        // malformed.
        let undecodableFiles = [
            // Because we use an enum to represent ReturnDocument, the invalid string present in this file "Invalid"
            // gives us a decoding error.
            "returnDocument-enum-invalid.json",
            // This has the same problem as the previous file, where an invalid string is provided, this time for
            // apiVersion.
            "entity-client-apiVersion-unsupported.json",
            // This test specifies a non-existent argument "foo" for an insertOne operation.
            "ignoreResultAndError-malformed.json",
            // This test is missing a required argument, "filter", for a find operation.
            "entity-findCursor-malformed.json"
        ]

        let skipValidFailFiles = [
            // libmongoc does not implement CMAP or expose this information to us.
            "assertNumberConnectionsCheckedOut.json",
            // We don't support storeEventsAsEntities yet. TODO: SWIFT-1077
            "entity-client-storeEventsAsEntities-conflict_within_different_array.json",
            "entity-client-storeEventsAsEntities-conflict_within_same_array.json",
            "entity-client-storeEventsAsEntities-conflict_with_client_id.json"
        ] + undecodableFiles

        let validFailTests = try retrieveSpecTestFiles(
            specName: "unified-test-format",
            subdirectory: "valid-fail",
            excludeFiles: skipValidFailFiles,
            asType: UnifiedTestFile.self
        )

        for (_, test) in validFailTests {
            // work around to expect(try await ...) bc expect is sync
            do {
                try await runner.runFiles([test])
            } catch {
                expect(error).toNot(beNil())
            }
        }
    }

    func testStrictDecodableTypes() throws {
        // Test decoding a valid key. Conveniently, this options is supported by 4 of the 5 StrictDecodable types.
        let validOptsRaw: BSONDocument = [
            "readPreference": "primary"
        ]

        expect(try BSONDecoder().decode(MongoDatabaseOptions.self, from: validOptsRaw)).toNot(throwError())
        expect(try BSONDecoder().decode(MongoCollectionOptions.self, from: validOptsRaw)).toNot(throwError())
        expect(try BSONDecoder().decode(MongoClientOptions.self, from: validOptsRaw)).toNot(throwError())
        expect(try BSONDecoder().decode(TransactionOptions.self, from: validOptsRaw)).toNot(throwError())

        let validSessionOptsRaw: BSONDocument = [
            "causalConsistency": true,
            "defaultTransactionOptions": .document(validOptsRaw)
        ]
        expect(try BSONDecoder().decode(ClientSessionOptions.self, from: validSessionOptsRaw)).toNot(throwError())

        // Test decoding from a document with an unsupported key errors.
        let invalidOptsRaw: BSONDocument = [
            "blah": "hi"
        ]
        expect(try BSONDecoder().decode(MongoDatabaseOptions.self, from: invalidOptsRaw))
            .to(throwError(errorType: TestError.self))
        expect(try BSONDecoder().decode(MongoCollectionOptions.self, from: invalidOptsRaw))
            .to(throwError(errorType: TestError.self))
        expect(try BSONDecoder().decode(MongoClientOptions.self, from: invalidOptsRaw))
            .to(throwError(errorType: TestError.self))
        expect(try BSONDecoder().decode(ClientSessionOptions.self, from: invalidOptsRaw))
            .to(throwError(errorType: TestError.self))
        expect(try BSONDecoder().decode(TransactionOptions.self, from: invalidOptsRaw))
            .to(throwError(errorType: TestError.self))

        // Test that we error when the invalid key is in a nested field (whose type also conforms to StrictDecodable).
        let invalidNestedOptsRaw: BSONDocument = [
            "defaultTransactionOptions": .document(invalidOptsRaw)
        ]
        expect(try BSONDecoder().decode(ClientSessionOptions.self, from: invalidNestedOptsRaw))
            .to(throwError(errorType: TestError.self))
    }

    func testServerParameterRequirements() throws {
        // "ok" isn't actually a parameter, it's just part of the command response, but is good for testing use
        // because assuming the command succeeds it will always be present and therefore "met".
        let meetableParamRequirements: [BSONDocument] = [
            ["ok": .int32(1)],
            ["ok": .int64(1)],
            ["ok": .double(1)],
            ["ok": .double(1.00001)]
        ]

        let client = try MongoClient.makeAsyncTestClient()
        // Need to close client since there's no automatic `deinit`
        defer {
            try! client.syncClose()
        }
        for params in meetableParamRequirements {
            let req = TestRequirement(serverParameters: params)
            expect(try client.getUnmetRequirement(req)).to(beNil())
        }

        let unmeetableParamRequirements: [BSONDocument] = [
            ["fakeParameterNameTheServerWillNeverUse": true],
            ["ok": 2],
            ["ok": "hi"]
        ]

        for param in unmeetableParamRequirements {
            let req = TestRequirement(serverParameters: param)
            let unmetReq = try client.getUnmetRequirement(req)
            switch unmetReq {
            case .serverParameter:
                continue
            default:
                fail("Expected server parameter requirement \(param) to be unmet, but was met")
            }
        }
    }
}
#endif
