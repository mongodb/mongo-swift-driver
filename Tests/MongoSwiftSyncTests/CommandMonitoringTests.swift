import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

let center = NotificationCenter.default

final class CommandMonitoringTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testCommandMonitoring() throws {
        guard MongoSwiftTestCase.topologyType != .sharded else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let client = try MongoClient.makeTestClient()
        let monitor = client.addCommandMonitor()

        let tests = try retrieveSpecTestFiles(specName: "command-monitoring", asType: CMTestFile.self)
        for (filename, testFile) in tests {
            // read in the file data and parse into a struct
            let name = filename.components(separatedBy: ".")[0]

            // TODO: SWIFT-346: remove this skip
            if name.lowercased().contains("bulkwrite") { continue }

            // remove this when command.json is updated with the new count API (see SPEC-1272)
            if name.lowercased() == "command" { continue }

            print("-----------------------")
            print("Executing tests for file \(name)...\n")

            // execute the tests for this file
            for var test in testFile.tests {
                if try !client.serverVersionIsInRange(test.minServerVersion, test.maxServerVersion) {
                    print("Skipping test case \(test.description) for server version \(try client.serverVersion())")
                    continue
                }

                print("Test case: \(test.description)")

                // Setup the specified DB and collection with provided data
                let db = client.db(testFile.databaseName)
                try db.drop() // In case last test run failed, drop to clear out DB
                let collection = try db.createCollection(testFile.collectionName)
                try collection.insertMany(testFile.data)

                try monitor.captureEvents {
                    try test.doOperation(withCollection: collection)
                }

                let receivedEvents = monitor.events()
                expect(receivedEvents).to(haveCount(test.expectations.count))

                for (receivedEvent, expectedEvent) in zip(receivedEvents, test.expectations) {
                    expectedEvent.compare(to: receivedEvent, testContext: &test.context)
                }

                try db.drop()
            }
        }
    }
}

/// A struct to hold the data for a single file, containing one or more tests.
private struct CMTestFile: Decodable {
    let data: [BSONDocument]
    let collectionName: String
    let databaseName: String
    let tests: [CMTest]
    let namespace: String?

    enum CodingKeys: String, CodingKey {
        case data, collectionName = "collection_name",
             databaseName = "database_name", tests, namespace
    }
}

/// A struct to hold the data for a single test from a CMTestFile.
private struct CMTest: Decodable {
    struct Operation: Decodable {
        let name: String
        let args: BSONDocument
        let readPreference: ReadPreference?

        enum CodingKeys: String, CodingKey {
            case name, args = "arguments", readPreference = "read_preference"
        }
    }

    let op: Operation
    let description: String
    let expectationDocs: [BSONDocument]
    let minServerVersion: String?
    let maxServerVersion: String?

    // Some tests contain cursors/getMores and we need to verify that the
    // IDs are consistent across sinlge operations. we store that data in this
    // `context` dictionary so we can access it in future events for the same test
    var context = [String: Any]()

    var expectations: [ExpectationType] { try! self.expectationDocs.map { try makeExpectation($0) } }

    enum CodingKeys: String, CodingKey {
        case description, op = "operation", expectationDocs = "expectations",
             minServerVersion = "ignore_if_server_version_less_than",
             maxServerVersion = "ignore_if_server_version_greater_than"
    }

    // Given a collection, perform the operation specified for this test on it.
    // try? each operation because we expect some of them to fail.
    // If something fails/succeeds incorrectly, we'll know because the generated
    // events won't match up.
    // swiftlint:disable cyclomatic_complexity
    func doOperation(withCollection collection: MongoCollection<BSONDocument>) throws {
        let filter: BSONDocument = self.op.args["filter"]?.documentValue ?? [:]

        switch self.op.name {
        case "count":
            let options = CountDocumentsOptions(readPreference: self.op.readPreference)
            _ = try? collection.countDocuments(filter, options: options)
        case "deleteMany":
            _ = try? collection.deleteMany(filter)
        case "deleteOne":
            _ = try? collection.deleteOne(filter)

        case "find":
            let modifiers = self.op.args["modifiers"]?.documentValue
            var hint: IndexHint?
            if let hintDoc = modifiers?["$hint"]?.documentValue {
                hint = .indexSpec(hintDoc)
            }
            let options = FindOptions(
                batchSize: self.op.args["batchSize"]?.toInt(),
                comment: modifiers?["$comment"]?.stringValue,
                hint: hint,
                limit: self.op.args["limit"]?.toInt(),
                max: modifiers?["$max"]?.documentValue,
                maxTimeMS: modifiers?["$maxTimeMS"]?.toInt(),
                min: modifiers?["$min"]?.documentValue,
                readPreference: self.op.readPreference,
                returnKey: modifiers?["$returnKey"]?.boolValue,
                showRecordID: modifiers?["$showDiskLoc"]?.boolValue,
                skip: self.op.args["skip"]?.toInt(),
                sort: self.op.args["sort"]?.documentValue
            )

            do {
                let cursor = try collection.find(filter, options: options)
                for _ in cursor {}
            } catch {}

        case "insertMany":
            let documents = (self.op.args["documents"]?.arrayValue?.compactMap { $0.documentValue })!
            let options = InsertManyOptions(ordered: self.op.args["ordered"]?.boolValue)
            _ = try? collection.insertMany(documents, options: options)

        case "insertOne":
            let document = self.op.args["document"]!.documentValue!
            _ = try? collection.insertOne(document)

        case "updateMany":
            let update = self.op.args["update"]!.documentValue!
            _ = try? collection.updateMany(filter: filter, update: update)

        case "updateOne":
            let update = self.op.args["update"]!.documentValue!
            let options = UpdateOptions(upsert: self.op.args["upsert"]?.boolValue)
            _ = try? collection.updateOne(filter: filter, update: update, options: options)

        default:
            XCTFail("Unrecognized operation name \(self.op.name)")
        }
    }

    // swiftlint:enable cyclomatic_complexity
}

/// A protocol for the different types of expected events to implement
private protocol ExpectationType {
    /// Compare this expectation's data to that in a `CommandEvent`, possibly
    /// using/adding to the provided test context
    func compare(to receivedEvent: CommandEvent, testContext: inout [String: Any])
}

/// Based on the name of the expectation, generate a corresponding
/// `ExpectationType` to be compared to incoming events
private func makeExpectation(_ document: BSONDocument) throws -> ExpectationType {
    let decoder = BSONDecoder()

    if let doc = document["command_started_event"]?.documentValue {
        return try decoder.decode(CommandStartedExpectation.self, from: doc)
    }

    if let doc = document["command_succeeded_event"]?.documentValue {
        return try decoder.decode(CommandSucceededExpectation.self, from: doc)
    }

    if let doc = document["command_failed_event"]?.documentValue {
        return try decoder.decode(CommandFailedExpectation.self, from: doc)
    }

    throw TestError(message: "Unknown expectation type in document \(document)")
}

/// An expectation for a `CommandStartedEvent`
private struct CommandStartedExpectation: ExpectationType, Decodable {
    var command: BSONDocument
    let commandName: String
    let databaseName: String

    enum CodingKeys: String, CodingKey {
        case command,
             commandName = "command_name",
             databaseName = "database_name"
    }

    func compare(to receivedEvent: CommandEvent, testContext: inout [String: Any]) {
        guard let event = receivedEvent.commandStartedValue else {
            XCTFail("Notification \(receivedEvent) did not contain a CommandStartedEvent")
            return
        }
        // compare the command and DB names
        expect(event.commandName).to(equal(self.commandName))
        expect(event.databaseName).to(equal(self.databaseName))

        // if it's a getMore, we can't directly compare the results
        if self.commandName == "getMore" {
            // verify that the getMore ID matches the stored cursor ID for this test
            expect(event.command["getMore"]).to(equal(testContext["cursorId"] as? BSON))
            // compare collection and batchSize fields
            expect(event.command["collection"]).to(equal(self.command["collection"]))
            expect(event.command["batchSize"]).to(equal(self.command["batchSize"]))
        } else {
            // remove fields from the command we received that are not in the expected
            // command, and reorder them, so we can do a direct comparison of the documents
            let normalizedSelf = normalizeCommand(self.command)
            let receivedCommand = rearrangeDoc(event.command, toLookLike: normalizedSelf)
            expect(receivedCommand).to(equal(normalizedSelf))
        }
    }
}

private func normalizeCommand(_ input: BSONDocument) -> BSONDocument {
    var output = BSONDocument()
    for (k, v) in input {
        // temporary fix pending resolution of SPEC-1049. removes the field
        // from the expected command unless if it is set to true, because none of the
        // tests explicitly provide upsert: false or multi: false, yet they
        // are in the expected commands anyway.
        if ["upsert", "multi"].contains(k), let bV = v.boolValue {
            if bV { output[k] = true } else { continue }

            // The tests don't explicitly store maxTimeMS as an Int64, so libmongoc
            // parses it as an Int32 which we convert to Int. convert to Int64 here because we
            // (as per the crud spec) use an Int64 for maxTimeMS and send that to
            // the server in our actual commands.
        } else if k == "maxTimeMS", let iV = v.toInt64() {
            output[k] = .int64(iV)

            // recursively normalize if it's a document
        } else if let docVal = v.documentValue {
            output[k] = .document(normalizeCommand(docVal))

            // recursively normalize each element if it's an array
        } else if case let .array(arrVal) = v {
            output[k] = .array(arrVal.map {
                switch $0 {
                case let .document(d):
                    return .document(normalizeCommand(d))
                default:
                    return $0
                }
            })

            // just copy the value over as is
        } else {
            output[k] = v
        }
    }
    return output
}

private struct CommandFailedExpectation: ExpectationType, Decodable {
    let commandName: String

    enum CodingKeys: String, CodingKey {
        case commandName = "command_name"
    }

    func compare(to receivedEvent: CommandEvent, testContext _: inout [String: Any]) {
        guard let event = receivedEvent.commandFailedValue else {
            XCTFail("Notification \(receivedEvent) did not contain a CommandFailedEvent")
            return
        }
        /// The only info we get here is the command name so just compare those
        expect(event.commandName).to(equal(self.commandName))
    }
}

private struct CommandSucceededExpectation: ExpectationType, Decodable {
    let originalReply: BSONDocument
    let commandName: String

    var reply: BSONDocument { normalizeExpectedReply(self.originalReply) }
    var writeErrors: [BSONDocument]? { self.originalReply["writeErrors"]?.arrayValue?.compactMap { $0.documentValue } }
    var cursor: BSONDocument? { self.originalReply["cursor"]?.documentValue }

    enum CodingKeys: String, CodingKey {
        case commandName = "command_name", originalReply = "reply"
    }

    func compare(to receivedEvent: CommandEvent, testContext: inout [String: Any]) {
        guard let event = receivedEvent.commandSucceededValue else {
            XCTFail("Notification \(receivedEvent) did not contain a CommandSucceededEvent")
            return
        }

        // compare everything excluding writeErrors and cursor
        let cleanedReply = rearrangeDoc(event.reply, toLookLike: self.reply)
        expect(cleanedReply).to(equal(self.reply))
        expect(event.commandName).to(equal(self.commandName))

        // compare writeErrors, if any
        let receivedWriteErrs = event.reply["writeErrors"]?.arrayValue?.compactMap { $0.documentValue }
        if let expectedErrs = self.writeErrors {
            expect(receivedWriteErrs).toNot(beNil())
            self.checkWriteErrors(expected: expectedErrs, actual: receivedWriteErrs!)
        } else {
            expect(receivedWriteErrs).to(beNil())
        }

        let receivedCursor = event.reply["cursor"]?.documentValue
        if let expectedCursor = self.cursor {
            // if the received cursor has an ID, and the expected ID is not 0, compare cursor IDs
            if let id = receivedCursor!["id"], expectedCursor["id"]?.toInt() != 0 {
                let storedId = testContext["cursorId"] as? BSON
                // if we aren't already storing a cursor ID for this test, add one
                if storedId == nil {
                    testContext["cursorId"] = id
                    // otherwise, verify that this ID matches the stored one
                } else {
                    expect(storedId).to(equal(id))
                }
            }
            self.compareCursors(expected: expectedCursor, actual: receivedCursor!)
        } else {
            expect(receivedCursor).to(beNil())
        }
    }

    /// Compare expected vs actual write errors.
    func checkWriteErrors(expected: [BSONDocument], actual: [BSONDocument]) {
        // The expected writeErrors has placeholder values,
        // so just make sure the count is the same
        expect(expected.count).to(equal(actual.count))
        for err in actual {
            // check each error code exists and is > 0
            expect(err["code"]?.toInt()).to(beGreaterThan(0))
            // check each error msg exists and has length > 0
            expect(err["errmsg"]?.stringValue).toNot(beEmpty())
        }
    }

    /// Compare expected vs actual cursor data, excluding the cursor ID
    /// (handled in `compare` because we need the test context).
    func compareCursors(expected: BSONDocument, actual: BSONDocument) {
        let ordered = rearrangeDoc(actual, toLookLike: expected)
        expect(ordered["ns"]).to(equal(expected["ns"]))
        if let firstBatch = expected["firstBatch"] {
            expect(ordered["firstBatch"]).to(equal(firstBatch))
        } else if let nextBatch = expected["nextBatch"] {
            expect(ordered["nextBatch"]).to(equal(nextBatch))
        }
    }
}

/// Clean up expected replies for easier comparison to received replies
private func normalizeExpectedReply(_ input: BSONDocument) -> BSONDocument {
    var output = BSONDocument()
    for (k, v) in input {
        // These fields both have placeholder values in them,
        // so we can't directly compare. Remove them from the expected
        // reply so we can == the remaining fields and compare
        // writeErrors and cursor separately.
        if ["writeErrors", "cursor"].contains(k) {
            continue
            // The server sends back doubles, but the JSON test files
            // contain integer statuses (see SPEC-1050.)
        } else if k == "ok", let dV = v.toDouble() {
            output[k] = .double(dV)
            // just copy the value over as is
        } else {
            output[k] = v
        }
    }
    return output
}
