@testable import MongoSwift
import Nimble
import XCTest

let center =  NotificationCenter.default

// TODO: don't hardcode this
let VERSION = "3.6"

final class CommandMonitoringTests: XCTestCase {
    static var allTests: [(String, (CommandMonitoringTests) -> () throws -> Void)] {
        return [
            ("testCommandMonitoring", testCommandMonitoring),
            ("testAlternateNotificationCenters", testAlternateNotificationCenters)
        ]
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    func testCommandMonitoring() throws {
        let client = try MongoClient(options: ClientOptions(eventMonitoring: true))
        client.enableMonitoring(forEvents: .commandMonitoring)

        let cmPath = self.getSpecsPath() + "/command-monitoring/tests"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: cmPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            // read in the file data and parse into a struct
            let name = filename.components(separatedBy: ".")[0]

            // remove this if/when bulkwrite is supported
            if name.lowercased().contains("bulkwrite") { continue }

            let testFilePath = URL(fileURLWithPath: "\(cmPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let testFile = try CMTestFile(fromDocument: asDocument)

            print("-----------------------")
            print("Executing tests for file \(name)...\n")

            // execute the tests for this file
            for var test in testFile.tests {

                // Check that the current version we're testing is within bounds for this cases
                if let maxVersion = test.maxServerVersion, maxVersion < VERSION {
                    continue
                } else if let minVersion = test.minServerVersion, VERSION < minVersion {
                    continue
                }

                print("Test case: \(test.description)")

                // 1. Setup the specified DB and collection with provided data
                let db = try client.db(testFile.databaseName)
                try db.drop() // In case last test run failed, drop to clear out DB
                let collection = try db.createCollection(testFile.collectionName)
                try collection.insertMany(testFile.data)

                // 2. Add an observer that looks for all events
                var expectedEvents = test.expectations
                let observer = center.addObserver(forName: nil, object: nil, queue: nil) { (notif) in
                    // ignore if it doesn't match one of the names we're looking for
                    if !["commandStarted", "commandSucceeded", "commandFailed"].contains(notif.name.rawValue) { return }

                    // remove the next expectation for this test and verify it matches the received event
                    if expectedEvents.count > 0 {
                        expectedEvents.removeFirst().compare(to: notif, testContext: &test.context)
                    } else {
                        XCTFail("Got a notification, but ran out of expected events")
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
        let db = try client.db("commandTest")
        let collection = try db.createCollection("coll1")
        let customCenter = NotificationCenter()
        client.enableMonitoring(forEvents: .commandMonitoring, usingCenter: customCenter)
        var eventCount = 0
        let observer = customCenter.addObserver(forName: nil, object: nil, queue: nil) { (_) in
            eventCount += 1
        }

        try collection.insertOne(["x": 1])
        expect(eventCount).to(beGreaterThan(0))
        customCenter.removeObserver(observer)

        try db.drop()
    }
}

/// A struct to hold the data for a single file, containing one or more tests.
private struct CMTestFile {
    let data: [Document]
    let collectionName: String
    let databaseName: String
    let tests: [CMTest]
    let namespace: String?

    init(fromDocument document: Document) throws {
        self.data = try document.get("data")
        self.collectionName = try document.get("collection_name")
        self.databaseName = try document.get("database_name")
        let tests: [Document] = try document.get("tests")
        self.tests = try tests.map { try CMTest(fromDocument: $0) }
        self.namespace = document["namespace"] as? String
    }
}

/// A struct to hold the data for a single test from a CMTestFile.
private struct CMTest {
    let description: String
    let operationName: String
    let args: Document
    let readPreference: Document?
    let expectations: [ExpectationType]
    let minServerVersion: String?
    let maxServerVersion: String?

    // Some tests contain cursors/getMores and we need to verify that the
    // IDs are consistent across sinlge operations. we store that data in this
    // `context` dictionary so we can access it in future events for the same test
    var context: [String: Any]

    init(fromDocument document: Document) throws {
        self.description = try document.get("description")
        let operation: Document = try document.get("operation")
        self.operationName = try operation.get("name")
        self.args = try operation.get("arguments")
        self.readPreference = operation["readPreference"] as? Document
        let expectationDocs: [Document] = try document.get("expectations")
        self.expectations = try expectationDocs.map { try makeExpectation($0) }
        self.minServerVersion = document["ignore_if_server_version_less_than"] as? String
        self.maxServerVersion = document["ignore_if_server_version_greater_than"] as? String
        self.context = [String: Any]()
    }

    // Given a collection, perform the operation specified for this test on it.
    // Wrap each operation in do/catch because we expect some of them to fail.
    // If something fails/succeeds incorrectly, we'll know because the generated
    // events won't match up.
    func doOperation(withCollection collection: MongoCollection<Document>) throws {
        // TODO SWIFT-31: use readPreferences for commands if provided
        let filter = self.args["filter"] as? Document
        switch self.operationName {

        case "count":
            do { _ = try collection.count(filter ?? [:]) } catch { }
        case "deleteMany":
            do { try collection.deleteMany(filter ?? [:]) } catch { }
        case "deleteOne":
            do { try collection.deleteOne(filter ?? [:]) } catch { }

        case "find":
            let modifiers = self.args["modifiers"] as? Document
            var batchSize: Int32?
            if let size = self.args["batchSize"] as? Int64 {
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
                                        limit: self.args["limit"] as? Int64,
                                        max: modifiers?["$max"] as? Document,
                                        maxTimeMS: maxTime,
                                        min: modifiers?["$min"] as? Document,
                                        returnKey: modifiers?["$returnKey"] as? Bool,
                                        showRecordId: modifiers?["$showDiskLoc"] as? Bool,
                                        skip: self.args["skip"] as? Int64,
                                        sort: self.args["sort"] as? Document)

            // we have to iterate the cursor to make the command execute
            do { for _ in try collection.find(filter ?? [:], options: options) {} } catch { }

        case "insertMany":
            let documents: [Document] = try self.args.get("documents")
            let options = InsertManyOptions(ordered: self.args["ordered"] as? Bool)
            do { try collection.insertMany(documents, options: options) } catch { }

        case "insertOne":
            let document: Document = try self.args.get("document")
            do { try collection.insertOne(document) } catch { }

        case "updateMany":
            let update: Document = try self.args.get("update")
            do { try collection.updateMany(filter: filter ?? [:], update: update) } catch { }

        case "updateOne":
            let update: Document = try self.args.get("update")
            let options = UpdateOptions(upsert: self.args["upsert"] as? Bool)
            do { try collection.updateOne(filter: filter ?? [:], update: update, options: options) } catch { }

        default:
            XCTFail("Unrecognized operation name \(self.operationName)")
        }
    }
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
    if let doc = document["command_started_event"] as? Document {
        return try CommandStartedExpectation(fromDocument: doc)
    } else if let doc = document["command_succeeded_event"] as? Document {
        return try CommandSucceededExpectation(fromDocument: doc)
    } else if let doc = document["command_failed_event"] as? Document {
        return try CommandFailedExpectation(fromDocument: doc)
    }
    throw TestError(message: "Unknown expectation type in document \(document)")
}

/// An expectation for a `CommandStartedEvent`
private struct CommandStartedExpectation: ExpectationType {
    let command: Document
    let commandName: String
    let databaseName: String

    init(fromDocument document: Document) throws {
        self.command = normalizeCommand(try document.get("command"))
        self.commandName = try document.get("command_name")
        self.databaseName = try document.get("database_name")
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
            expect(event.command["getMore"] as? Int64).to(equal(testContext["cursorId"] as? Int64))
            // compare collection and batchSize fields
            expect(event.command["collection"] as? String).to(equal(self.command["collection"] as? String))
            expect(event.command["batchSize"] as? Int64).to(equal(self.command["batchSize"] as? Int64))
        } else {
            // remove fields from the command we received that are not in the expected
            // command, and reorder them, so we can do a direct comparison of the documents
            let receivedCommand = rearrangeDoc(event.command, toLookLike: self.command)
            expect(receivedCommand).to(equal(self.command))
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

private struct CommandFailedExpectation: ExpectationType {
    let commandName: String

    init(fromDocument document: Document) throws {
        self.commandName = try document.get("command_name")
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

private struct CommandSucceededExpectation: ExpectationType {
    let reply: Document
    let writeErrors: [Document]?
    let cursor: Document?
    let commandName: String

    init(fromDocument document: Document) throws {
        let originalReply: Document = try document.get("reply")
        self.reply = normalizeExpectedReply(originalReply)
        self.writeErrors = originalReply["writeErrors"] as? [Document] ?? nil
        self.cursor = originalReply["cursor"] as? Document ?? nil
        self.commandName = try document.get("command_name")
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
        expect(ordered["ns"] as? String).to(equal(expected["ns"] as? String))
        if let firstBatch = expected["firstBatch"] as? [Document] {
            expect(ordered["firstBatch"] as? [Document]).to(equal(firstBatch))
        } else if let nextBatch = expected["nextBatch"] as? [Document] {
            expect(ordered["nextBatch"] as? [Document]).to(equal(nextBatch))
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
