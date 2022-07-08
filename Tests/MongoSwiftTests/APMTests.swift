@testable import MongoSwift
import Nimble
import NIOConcurrencyHelpers
import TestsCommon

final class APMTests: MongoSwiftTestCase {
    func testCommandEventStreamClient() async throws {
        try await self.withTestClient { client in
            let commandStr: [String] = ["ping", "ping", "endSessions", "endSessions"]
            let eventTypes: [EventType] = [
                .commandStartedEvent,
                .commandSucceededEvent,
                .commandStartedEvent,
                .commandSucceededEvent
            ]
            // let cmdEventsTask = Task { () -> Int in
            Task {
                var i = 0
                for try await event in client.commandEvents {
                    expect(commandStr[i]).to(equal(event.commandName))
                    expect(eventTypes[i]).to(equal(event.type))
                    i += 1
                }
                // return i
            }

            try await client.db("admin").runCommand(["ping": 1])
//            try await client.close()
//            let taskResult =  await cmdEventsTask.result
//            do {
//                let output = try taskResult.get()
//                expect(output).to(equal(4))
//            } catch {
//                print("oopsies")
//            }
        }
    }

    func testSDAMEventStreamClient() async throws {
        // Need lock to prevent dataraces
        let lock = Lock()
        try await self.withTestClient { client in
            Task {
                var i = 0
                var eventTypes: [EventType] = []
                // Lock the array access while appending
                lock.withLock {
                    client.addSDAMEventHandler { event in
                        if !event.isHeartbeatEvent {
                            eventTypes.append(event.type)
                        }
                    }
                }
                // Async so cannot lock
                for try await event in client.sdamEvents {
                    if !event.isHeartbeatEvent {
                        expect(event.type).to(equal(eventTypes[i]))
                        i += 1
                    }
                }
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
        }
    }
}
