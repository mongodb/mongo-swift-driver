#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import NIOConcurrencyHelpers
import TestsCommon

@available(macOS 10.15, *)
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
            Task {
                var i = 0
                let cmdStream = client.commandEventStream()
                for try await event in cmdStream {
                    print("cmd-event")
                    expect(commandStr[i]).to(equal(event.commandName))
                    expect(eventTypes[i]).to(equal(event.type))
                    i += 1
                    if i == 4 {
                        cmdStream.finish()
                    }
                }
                expect(i).to(be(4))
            }

            try await client.db("admin").runCommand(["ping": 1])
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
                let sdamStream = client.sdamEventStream()
                for try await event in sdamStream {
                    if !event.isHeartbeatEvent {
                        expect(event.type).to(equal(eventTypes[i]))
                        i += 1
                    }
                }
                // Doesnt exit since we dont .finish()
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
        }
    }
}
#endif
