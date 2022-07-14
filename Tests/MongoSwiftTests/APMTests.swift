#if compiler(>=5.5.2) && canImport(_Concurrency)
import MongoSwift
import Nimble
import NIO
import NIOConcurrencyHelpers
import TestsCommon

@available(macOS 10.15, *)
final class APMTests: MongoSwiftTestCase {
    func testClientFinishesCommandStreams() async throws {
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { elg.syncShutdownOrFail() }
        let client = try MongoClient.makeTestClient(eventLoopGroup: elg)

        // Task to create a commandEventStream and should return when the client is closed
        let eventTask = Task { () -> Bool in
            // let cmdStream = client.commandEventStream()
            for try await _ in client.commandEventStream() {
                print("here")
            }
            print("out of loop")
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
                print(event.commandName)
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

    func testCommandStreamConcurrentStreams() async throws {
        actor CmdEventArray {
            var eventTypes: [[EventType]] = []
            var eventCommands: [[String]] = []

            func appendType(eventType: EventType, index: Int) {
                self.eventTypes[index].append(eventType)
            }

            func appendCommands(commandEvent: String, index: Int) {
                self.eventCommands[index].append(commandEvent)
            }

            func newTask() {
                // let currSize = self.eventTypes.count
                self.eventTypes.append([])
                self.eventCommands.append([])
                print("here")
            }

            func isRectangular() -> Bool {
                let size = self.eventTypes[0].count
                for entry in self.eventTypes where entry.count != size {
                    return false
                }
                return true
            }
        }
        let cmdEventArray = CmdEventArray()
        try await self.withTestClient { client in
            // Task to create a commandEventStream and should return when the client is closed

            for i in 0...4 {
                _ = Task { () -> Bool in
                    await cmdEventArray.newTask()
                    let p = await cmdEventArray.eventTypes.count
                    print(String(p) + " " + String(i))
//                    try await assertIsEventuallyTrue(description: "event stream should be started") {
//                        await cmdEventArray.eventTypes.count == i + 1
//                    }
                    for try await event in client.commandEventStream() {
                        // print(event.commandName)
                        await cmdEventArray.appendType(eventType: event.type, index: i)
                        await cmdEventArray.appendCommands(commandEvent: event.commandName, index: i)
                    }

                    return true
                }
            }

            try await client.db("admin").runCommand(["ping": 1])
            //try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
            try await assertIsEventuallyTrue(description: "5 tasks started") {
                await cmdEventArray.eventTypes.count == 5
            }
            try await assertIsEventuallyTrue(description: "each task gets same events") {
                await cmdEventArray.isRectangular()
            }
        }
        // Expect all tasks received the same number (>0) of events
        for i in 0...4 {
            let eventTypes = await cmdEventArray.eventTypes[i]
            let eventCommands = await cmdEventArray.eventCommands[i]
            expect(eventTypes.count).to(beGreaterThan(0))
            expect(eventCommands.count).to(beGreaterThan(0))
        }
        for i in 1...4 {
            let eventTypesOld = await cmdEventArray.eventTypes[i - 1]
            let eventCommandsOld = await cmdEventArray.eventCommands[i - 1]
            let eventTypesCurr = await cmdEventArray.eventTypes[i]
            let eventCommandsCurr = await cmdEventArray.eventCommands[i]
            expect(eventTypesOld).to(equal(eventTypesCurr))
            expect(eventCommandsOld).to(equal(eventCommandsCurr))
        }
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
                // print(i)
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

    // Need SDAM impl
    func testSDAMStreamConcurrentStreams() async throws {
        actor SdamEventArray {
            var eventTypes: [[EventType]] = []

            func appendType(eventType: EventType, index: Int) {
                self.eventTypes[index].append(eventType)
            }

            func newTask() {
                self.eventTypes.append([])
            }
        }
        let sdamEventArray = SdamEventArray()
        try await self.withTestClient { client in
            // Task to create a commandEventStream and should return when the client is closed

            for i in 0...4 {
                _ = Task { () -> Bool in
                    await sdamEventArray.newTask()
                    for try await event in client.sdamEventStream() {
                        // print(event.commandName)
                        await sdamEventArray.appendType(eventType: event.type, index: i)
                    }
                    return true
                }
            }
            try await assertIsEventuallyTrue(description: "event stream should be started") {
                await sdamEventArray.eventTypes.count == 5
            }

            try await client.db("admin").runCommand(["ping": 1])
            try await client.db("trialDB").collection("trialColl").insertOne(["hello": "world"])
        }
        // Expect all tasks received the same number (>0) of events
        for i in 0...4 {
            let eventTypes = await sdamEventArray.eventTypes[i]
            expect(eventTypes.count).to(beGreaterThan(0))
        }
        for i in 1...4 {
            let eventTypesOld = await sdamEventArray.eventTypes[i - 1]
            let eventTypesCurr = await sdamEventArray.eventTypes[i]
            expect(eventTypesOld).to(equal(eventTypesCurr))
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
