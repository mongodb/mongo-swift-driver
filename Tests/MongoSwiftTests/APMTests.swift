#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import NIO
import NIOConcurrencyHelpers
import TestsCommon

@available(macOS 10.15, *)

private protocol StreamableEvent {
    var type: EventType { get }
}

extension CommandEvent: StreamableEvent {}

extension SDAMEvent: StreamableEvent {}

final class APMTests: MongoSwiftTestCase {
    func testClientFinishesCommandStreams() async throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)

        // Task to create a commandEventStream and should return when the client is closed
        let eventTask = Task { () -> Bool in
            for try await _ in client.commandEventStream() {}
            return true
        }
        try await client.db("admin").runCommand(["ping": 1])
        try await client.close()

        // Ensure the task returned eventually
        _ = try await eventTask.value
    }

    func testCommandStreamHasCorrectEvents() async throws {
        let commandStr: [String] = ["ping", "ping", "endSessions", "endSessions"]
        let eventTypes: [EventType] = [
            .commandStartedEvent,
            .commandSucceededEvent,
            .commandStartedEvent,
            .commandSucceededEvent
        ]
        let clientTask = try await self.withTestClient { client -> Task<Int, Error> in
            let cmdTask = Task { () -> Int in
                var i = 0
                for try await event in client.commandEventStream() {
                    expect(event.commandName).to(equal(commandStr[i]))
                    expect(event.type).to(equal(eventTypes[i]))
                    i += 1
                }
                return i
            }

            try await client.db("admin").runCommand(["ping": 1])
            return cmdTask
        }
        let numEvents = try await clientTask.value
        expect(numEvents).to(equal(4))
    }

    func testCommandStreamBufferingPolicy() async throws {
        let insertsDone = NIOAtomic<Bool>.makeAtomic(value: false)
        let clientTask = try await self.withTestNamespace { client, _, coll -> Task<Int, Error> in
            let cmdBufferTask = Task { () -> Int in
                var i = 0
                let stream = client.commandEventStream()
                try await assertIsEventuallyTrue(description: "inserts done") {
                    insertsDone.load()
                }

                for try await _ in stream {
                    i += 1
                }
                return i
            }
            for _ in 1...60 { // 120 events
                try await coll.insertOne(["hello": "world"])
            }
            insertsDone.store(true)
            return cmdBufferTask
        }
        let numEventsBuffer = try await clientTask.value
        // Cant check for exactly 100 because of potential load balancer events getting added in during loop
        expect(numEventsBuffer).to(beLessThan(120))
    }

    /// Helper that tests kicking off multiple streams concurrently
    fileprivate func concurrentStreamTestHelper<T>(f: @escaping (MongoClient) -> T) async throws
        where T: AsyncSequence, T.Element: StreamableEvent
    {
        var taskArr: [Task<[EventType], Error>] = []
        try await self.withTestNamespace { client, _, coll in
            // Kick off 5 streams
            for _ in 0...4 {
                let task = Task { () -> [EventType] in
                    var eventArr: [EventType] = []
                    for try await event in f(client) {
                        eventArr.append(event.type)
                    }

                    return eventArr
                }
                taskArr.append(task)
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await coll.insertOne(["hello": "world"])
        }
        // Tasks start and finish
        try await assertIsEventuallyTrue(description: "each task is started") {
            taskArr.count == 5
        }

        // Expect all tasks received the same number (>0) of events
        for i in 0...4 {
            let eventArrOutput = try await taskArr[i].value
            expect(eventArrOutput.count).to(beGreaterThan(0))
        }
        for i in 1...4 {
            let eventArrOld = try await taskArr[i - 1].value
            let eventArrCurr = try await taskArr[i].value
            expect(eventArrOld).to(equal(eventArrCurr))
        }
    }

    func testCommandStreamConcurrentStreams() async throws {
        try await self.concurrentStreamTestHelper { client in
            client.commandEventStream()
        }
    }

    func testSDAMStreamConcurrentStreams() async throws {
        try await self.concurrentStreamTestHelper { client in
            client.sdamEventStream()
        }
    }

    func testClientFinishesSDAMStreams() async throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)

        // Task to create a commandEventStream and should return when the client is closed
        let eventTask = Task { () -> Bool in
            for try await _ in client.sdamEventStream() {}
            return true
        }
        try await client.db("admin").runCommand(["ping": 1])
        try await client.close()

        // Ensure the task returned eventually
        _ = try await eventTask.value
    }

    func testSDAMEventStreamHasCorrectEvents() async throws {
        let taskStarted = NIOAtomic<Bool>.makeAtomic(value: false)
        // Events seen by the regular SDAM handler
        var handlerEvents: [EventType] = []
        let clientTask = try await self.withTestNamespace { client, _, coll -> Task<[EventType], Error> in
            client.addSDAMEventHandler { event in
                if !event.isHeartbeatEvent {
                    handlerEvents.append(event.type)
                }
            }

            let sdamTask = Task { () -> [EventType] in
                var eventTypeSdam: [EventType] = []
                taskStarted.store(true)
                for try await event in client.sdamEventStream() {
                    if !event.isHeartbeatEvent {
                        eventTypeSdam.append(event.type)
                    }
                }
                return eventTypeSdam
            }
            // Wait until the event stream has been opened before we start inserting data.
            try await assertIsEventuallyTrue(description: "event stream should be started") {
                taskStarted.load()
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await coll.insertOne(["hello": "world"])
            return sdamTask
        }
        let streamEvents = try await clientTask.value
        expect(streamEvents.count).to(beGreaterThan(0))
        expect(streamEvents).to(equal(handlerEvents))
    }
}
#endif
