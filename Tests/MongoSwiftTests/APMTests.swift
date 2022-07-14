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
            // let cmdStream = client.commandEventStream()
            for try await _ in client.commandEventStream() {}
            return true
        }
        try await client.db("admin").runCommand(["ping": 1])
        try await client.close()

        // Ensure the task returned eventually
        _ = try await eventTask.value
    }

    func testCommandStreamHasCorrectEvents() async throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)
        let commandStr: [String] = ["ping", "ping", "endSessions", "endSessions"]
        let eventTypes: [EventType] = [
            .commandStartedEvent,
            .commandSucceededEvent,
            .commandStartedEvent,
            .commandSucceededEvent
        ]

        // Task to create a commandEventStream and should return when the client is closed
        let eventTask = Task { () -> Int in
            var i = 0
            for try await event in client.commandEventStream() {
                expect(event.commandName).to(equal(commandStr[i]))
                expect(event.type).to(equal(eventTypes[i]))
                i += 1
            }
            return i
        }
        try await client.db("admin").runCommand(["ping": 1])
        try await client.close()

        // Ensure the task returned with proper number of events
        let numEvents = try await eventTask.value
        expect(numEvents).to(equal(4))
    }

    func testCommandStreamBufferingPolicy() async throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)
        let insertsDone = NIOAtomic<Bool>.makeAtomic(value: false)

        let taskBuffer = Task { () -> Int in
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
        for i in 1...60 { // 120 events
            try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
            if i == 60 { insertsDone.store(true) }
        }
        try await client.close()
        let eventTypes1 = try await taskBuffer.value
        expect(eventTypes1).to(equal(100))
    }

    // Actor to handle array access/modification in an async way
    actor EventArray {
        var eventTypes: [[EventType]] = []
        var tasks: [Task<Bool, Error>] = []

        func appendType(eventType: EventType, index: Int) {
            self.eventTypes[index].append(eventType)
        }

        func appendTasks(task: Task<Bool, Error>) {
            self.tasks.append(task)
        }

        func newTask() {
            self.eventTypes.append([])
        }

        func getResults() async throws -> [Bool] {
            var output: [Bool] = []
            for elt in self.tasks {
                try await output.append(elt.value)
            }
            return output
        }
    }

    /// Helper that tests kicking off multiple streams concurrently
    fileprivate func concurrencyHelper<T>(f: @escaping (MongoClient) -> T) async throws
        where T: AsyncSequence, T.Element: StreamableEvent
    {
        let eventArray = EventArray()
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)

        // Kick off 5 streams
        for i in 0...4 {
            let task = Task { () -> Bool in
                await eventArray.newTask()
                for try await event in f(client) {
                    await eventArray.appendType(eventType: event.type, index: i)
                }

                return true
            }
            await eventArray.appendTasks(task: task)
        }

        try await client.db("admin").runCommand(["ping": 1])
        try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])

        // Tasks start, close client, close all tasks
        try await assertIsEventuallyTrue(description: "each task is started") {
            await eventArray.eventTypes.count == 5
        }

        try await client.close()
        try await assertIsEventuallyTrue(description: "each task is closed") {
            try await eventArray.getResults().count == 5
        }
        // Expect all tasks received the same number (>0) of events
        for i in 0...4 {
            let eventTypes = await eventArray.eventTypes[i]
            expect(eventTypes.count).to(beGreaterThan(0))
        }
        for i in 1...4 {
            let eventTypesOld = await eventArray.eventTypes[i - 1]
            let eventTypesCurr = await eventArray.eventTypes[i]
            expect(eventTypesOld).to(equal(eventTypesCurr))
        }
    }

    func testCommandStreamConcurrentStreams() async throws {
        try await self.concurrencyHelper { client in
            client.commandEventStream()
        }
    }

    func testSDAMStreamConcurrentStreams() async throws {
        try await self.concurrencyHelper { client in
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
        actor EventArray {
            var streamEvents: [EventType] = []

            func append(event: EventType) {
                self.streamEvents.append(event)
            }
        }
        // Need lock to prevent dataraces
        let lock = Lock()
        let taskStarted = NIOAtomic<Bool>.makeAtomic(value: false)
        var handlerEvents: [EventType] = []
        let eventArray = EventArray()
        try await self.withTestClient { client in
            client.addSDAMEventHandler { event in
                lock.withLock {
                    if !event.isHeartbeatEvent {
                        handlerEvents.append(event.type)
                    }
                }
            }
            Task {
                let sdamStream = client.sdamEventStream()
                taskStarted.store(true)
                for try await event in sdamStream {
                    if !event.isHeartbeatEvent {
                        await eventArray.append(event: event.type)
                    }
                }
            }
            // Wait until the event stream has been opened before we start inserting data.
            try await assertIsEventuallyTrue(description: "event stream should be started") {
                taskStarted.load()
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
        }
        let streamEvents = await eventArray.streamEvents
        expect(streamEvents).to(equal(handlerEvents))
    }
}
#endif
