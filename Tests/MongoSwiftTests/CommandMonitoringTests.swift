@testable import MongoSwift
import Nimble
import XCTest

let center = NotificationCenter.default

final class CommandMonitoringTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testCommandMonitoring() throws {
        let decoder = BSONDecoder()
        let client = try MongoClient(options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring(forEvents: .commandMonitoring)

        let cmPath = MongoSwiftTestCase.specsPath + "/command-monitoring/tests"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: cmPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            // read in the file data and parse into a struct
            let name = filename.components(separatedBy: ".")[0]

            // remove this if/when bulkwrite is supported
            if name.lowercased().contains("bulkwrite") { continue }

            let testFilePath = URL(fileURLWithPath: "\(cmPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let testFile = try decoder.decode(CMTestFile.self, from: asDocument)

            print("-----------------------")
            print("Executing tests for file \(name)...\n")

            // execute the tests for this file
            for var test in testFile.tests {
                if try !client.serverVersionIsInRange(test.minServerVersion, test.maxServerVersion) {
                    print("Skipping test case \(test.description) for server version \(try client.serverVersion())")
                    continue
                }

                print("Test case: \(test.description)")

                // 1. Setup the specified DB and collection with provided data
                let db = client.db(testFile.databaseName)
                try db.drop() // In case last test run failed, drop to clear out DB
                let collection = try db.createCollection(testFile.collectionName)
                try collection.insertMany(testFile.data)

                // 2. Add an observer that looks for all events
                var expectedEvents = test.expectations
                let observer = center.addObserver(forName: nil, object: nil, queue: nil) { notif in
                    // ignore if it doesn't match one of the names we're looking for
                    guard ["commandStarted", "commandSucceeded", "commandFailed"].contains(notif.name.rawValue) else {
                        return
                    }

                    // remove the next expectation for this test and verify it matches the received event
                    if expectedEvents.isEmpty {
                        XCTFail("Got a notification, but ran out of expected events")
                    } else {
                        expectedEvents.removeFirst().compare(to: notif, testContext: &test.context)
                    }
                }

                // 3. Perform the specified operation on this collection
                try test.doOperation(withCollection: collection)

                // 4. Make sure there aren't any events remaining that we didn't receive
                expect(expectedEvents).to(haveCount(0))

                // 5. Cleanup: remove observer and drop the DB
                center.removeObserver(observer)
                try db.drop()
            }
        }
    }

    func testAlternateNotificationCenters() throws {
        let client = try MongoClient(options: ClientOptions(eventMonitoring: true))
        let db = client.db(type(of: self).testDatabase)
        let collection = try db.createCollection(self.getCollectionName())
        let customCenter = NotificationCenter()
        client.enableMonitoring(forEvents: .commandMonitoring, usingCenter: customCenter)
        var eventCount = 0
        let observer = customCenter.addObserver(forName: nil, object: nil, queue: nil) { _ in
            eventCount += 1
        }

        try collection.insertOne(["x": 1])
        expect(eventCount).to(beGreaterThan(0))
        customCenter.removeObserver(observer)

        try db.drop()
    }
}

/// A struct to hold the data for a single file, containing one or more tests.
private struct CMTestFile: Decodable {
    let data: [Document]
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
        let args: Document
        let readPreference: Document?

        enum CodingKeys: String, CodingKey {
            case name, args = "arguments", readPreference
        }
    }

    let op: Operation
    let description: String
    let expectationDocs: [Document]
    let minServerVersion: String?
    let maxServerVersion: String?

    // Some tests contain cursors/getMores and we need to verify that the
    // IDs are consistent across sinlge operations. we store that data in this
    // `context` dictionary so we can access it in future events for the same test
    var context = [String: Any]()

    var expectations: [ExpectationType] { return try! expectationDocs.map { try makeExpectation($0) } }

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
    func doOperation(withCollection collection: MongoCollection<Document>) throws {
        // TODO SWIFT-31: use readPreferences for commands if provided
        let filter: Document = self.op.args["filter"] as? Document ?? [:]

        switch self.op.name {
        case "count":
            _ = try? collection.count(filter)
        case "deleteMany":
            _ = try? collection.deleteMany(filter)
        case "deleteOne":
            _ = try? collection.deleteOne(filter)

        case "find":
            let modifiers = self.op.args["modifiers"] as? Document
            var batchSize: Int32?
            if let size = self.op.args["batchSize"] as? Int64 {
                batchSize = Int32(size)
            }
            var maxTime: Int64?
            if let max = modifiers?["$maxTimeMS"] as? Int {
                maxTime = Int64(max)
            }
            var hint: Hint?
            if let hintDoc = modifiers?["$hint"] as? Document {
                hint = .indexSpec(hintDoc)
            }
            let options = FindOptions(batchSize: batchSize,
                                      comment: modifiers?["$comment"] as? String,
                                      hint: hint,
                                      limit: self.op.args["limit"] as? Int64,
                                      max: modifiers?["$max"] as? Document,
                                      maxTimeMS: maxTime,
                                      min: modifiers?["$min"] as? Document,
                                      returnKey: modifiers?["$returnKey"] as? Bool,
                                      showRecordId: modifiers?["$showDiskLoc"] as? Bool,
                                      skip: self.op.args["skip"] as? Int64,
                                      sort: self.op.args["sort"] as? Document)

            // we have to iterate the cursor to make the command execute
            for _ in try! collection.find(filter, options: options) {}

        case "insertMany":
            let documents: [Document] = try self.op.args.get("documents")
            let options = InsertManyOptions(ordered: self.op.args["ordered"] as? Bool)
            _ = try? collection.insertMany(documents, options: options)

        case "insertOne":
            let document: Document = try self.op.args.get("document")
            _ = try? collection.insertOne(document)

        case "updateMany":
            let update: Document = try self.op.args.get("update")
            _ = try? collection.updateMany(filter: filter, update: update)

        case "updateOne":
            let update: Document = try self.op.args.get("update")
            let options = UpdateOptions(upsert: self.op.args["upsert"] as? Bool)
            _ = try? collection.updateOne(filter: filter, update: update, options: options)

        default:
            XCTFail("Unrecognized operation name \(self.op.name)")
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

/// A protocol for the different types of expected events to implement
private protocol ExpectationType {
    /// Compare this expectation's data to that in a `Notification`, possibly
    /// using/adding to the provided test context
    func compare(to notification: Notification, testContext: inout [String: Any])
}

/// Based on the name of the expectation, generate a corresponding
/// `ExpectationType` to be compared to incoming events
private func makeExpectation(_ document: Document) throws -> ExpectationType {
    let decoder = BSONDecoder()

    if let doc = document["command_started_event"] as? Document {
        return try decoder.decode(CommandStartedExpectation.self, from: doc)
    }

    if let doc = document["command_succeeded_event"] as? Document {
        return try decoder.decode(CommandSucceededExpectation.self, from: doc)
    }

    if let doc = document["command_failed_event"] as? Document {
        return try decoder.decode(CommandFailedExpectation.self, from: doc)
    }

    throw TestError(message: "Unknown expectation type in document \(document)")
}

/// An expectation for a `CommandStartedEvent`
private struct CommandStartedExpectation: ExpectationType, Decodable {
    var command: Document
    let commandName: String
    let databaseName: String

    enum CodingKeys: String, CodingKey {
        case command,
        commandName = "command_name",
        databaseName = "database_name"
    }

    func compare(to notification: Notification, testContext: inout [String: Any]) {
        guard let event = notification.userInfo?["event"] as? CommandStartedEvent else {
            XCTFail("Notification \(notification) did not contain a CommandStartedEvent")
            return
        }
        // compare the command and DB names
        expect(event.commandName).to(equal(self.commandName))
        expect(event.databaseName).to(equal(self.databaseName))

        // if it's a getMore, we can't directly compare the results
        if commandName == "getMore" {
            // verify that the getMore ID matches the stored cursor ID for this test
            expect(event.command["getMore"]).to(bsonEqual(testContext["cursorId"] as? Int64))
            // compare collection and batchSize fields
            expect(event.command["collection"]).to(bsonEqual(self.command["collection"]))
            expect(event.command["batchSize"]).to(bsonEqual(self.command["batchSize"]))
        } else {
            // remove fields from the command we received that are not in the expected
            // command, and reorder them, so we can do a direct comparison of the documents
            let normalizedSelf = normalizeCommand(self.command)
            let receivedCommand = rearrangeDoc(event.command, toLookLike: normalizedSelf)
            expect(receivedCommand).to(equal(normalizedSelf))
        }
    }
}

private func normalizeCommand(_ input: Document) -> Document {
    var output = Document()
    for (k, v) in input {
        // temporary fix pending resolution of SPEC-1049. removes the field
        // from the expected command unless if it is set to true, because none of the
        // tests explicitly provide upsert: false or multi: false, yet they
        // are in the expected commands anyway.
        if ["upsert", "multi"].contains(k), let bV = v as? Bool {
            if bV { output[k] = true } else { continue }

        // The tests don't explicitly store maxTimeMS as an Int64, so libmongoc
        // parses it as an Int32 which we convert to Int. convert to Int64 here because we
        /// (as per the crud spec) use an Int64 for maxTimeMS and send that to
        // the server in our actual commands.
        } else if k == "maxTimeMS", let iV = v as? Int {
            output[k] = Int64(iV)

        // The expected batch sizes are always Int64s, however, find command
        // events actually have Int32 batch sizes... (as the spec says...)
        // but getMores have Int64s. so only convert if it's a find command...
        } else if k == "batchSize", let iV = v as? Int64 {
            if input["find"] != nil { output[k] = Int(iV) } else { output[k] = v }

        // recursively normalize if it's a document
        } else if let docVal = v as? Document {
            output[k] = normalizeCommand(docVal)

        // recursively normalize each element if it's an array
        } else if let arrVal = v as? [Document] {
            output[k] = arrVal.map { normalizeCommand($0) }

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

    func compare(to notification: Notification, testContext: inout [String: Any]) {
        guard let event = notification.userInfo?["event"] as? CommandFailedEvent else {
            XCTFail("Notification \(notification) did not contain a CommandFailedEvent")
            return
        }
        /// The only info we get here is the command name so just compare those
        expect(event.commandName).to(equal(self.commandName))
    }
}

private struct CommandSucceededExpectation: ExpectationType, Decodable {
    let originalReply: Document
    let commandName: String

    var reply: Document { return normalizeExpectedReply(originalReply) }
    var writeErrors: [Document]? { return originalReply["writeErrors"] as? [Document] }
    var cursor: Document? { return originalReply["cursor"] as? Document }

    enum CodingKeys: String, CodingKey {
        case commandName = "command_name", originalReply = "reply"
    }

    func compare(to notification: Notification, testContext: inout [String: Any]) {
        guard let event = notification.userInfo?["event"] as? CommandSucceededEvent else {
            XCTFail("Notification \(notification) did not contain a CommandSucceededEvent")
            return
        }

        // compare everything excluding writeErrors and cursor
        let cleanedReply = rearrangeDoc(event.reply, toLookLike: self.reply)
        expect(cleanedReply).to(equal(self.reply))
        expect(event.commandName).to(equal(self.commandName))

        // compare writeErrors, if any
        let receivedWriteErrs = event.reply["writeErrors"] as? [Document]
        if let expectedErrs = self.writeErrors {
            expect(receivedWriteErrs).toNot(beNil())
            checkWriteErrors(expected: expectedErrs, actual: receivedWriteErrs!)
        } else {
            expect(receivedWriteErrs).to(beNil())
        }

        let receivedCursor = event.reply["cursor"] as? Document
        if let expectedCursor = self.cursor {
            // if the received cursor has an ID, and the expected ID is not 0, compare cursor IDs
            if let id = receivedCursor!["id"] as? Int64, expectedCursor["id"] as? Int64 != 0 {
                let storedId = testContext["cursorId"] as? Int64
                // if we aren't already storing a cursor ID for this test, add one
                if storedId == nil {
                    testContext["cursorId"] = id
                // otherwise, verify that this ID matches the stored one
                } else {
                    expect(storedId).to(equal(id))
                }
            }
            compareCursors(expected: expectedCursor, actual: receivedCursor!)
        } else {
            expect(receivedCursor).to(beNil())
        }
    }

    /// Compare expected vs actual write errors.
    func checkWriteErrors(expected: [Document], actual: [Document]) {
        // The expected writeErrors has placeholder values,
        // so just make sure the count is the same
        expect(expected.count).to(equal(actual.count))
        for err in actual {
            // check each error code exists and is > 0
            expect(err["code"] as? Int).to(beGreaterThan(0))
            // check each error msg exists and has length > 0
            expect(err["errmsg"] as? String).toNot(beEmpty())
        }
    }

    /// Compare expected vs actual cursor data, excluding the cursor ID
    /// (handled in `compare` because we need the test context).
    func compareCursors(expected: Document, actual: Document) {
        let ordered = rearrangeDoc(actual, toLookLike: expected)
        expect(ordered["ns"]).to(bsonEqual(expected["ns"]))
        if let firstBatch = expected["firstBatch"] as? [Document] {
            expect(ordered["firstBatch"]).to(bsonEqual(firstBatch))
        } else if let nextBatch = expected["nextBatch"] as? [Document] {
            expect(ordered["nextBatch"]).to(bsonEqual(nextBatch))
        }
    }
}

/// Clean up expected replies for easier comparison to received replies
private func normalizeExpectedReply(_ input: Document) -> Document {
    var output = Document()
    for (k, v) in input {
        // These fields both have placeholder values in them,
        // so we can't directly compare. Remove them from the expected
        // reply so we can == the remaining fields and compare
        // writeErrors and cursor separately.
        if ["writeErrors", "cursor"].contains(k) {
            continue
        // The server sends back doubles, but the JSON test files
        // contain integer statuses (see SPEC-1050.)
        } else if k == "ok", let dV = v as? Int {
            output[k] = Double(dV)
        // just copy the value over as is
        } else {
            output[k] = v
        }
    }
    return output
}
