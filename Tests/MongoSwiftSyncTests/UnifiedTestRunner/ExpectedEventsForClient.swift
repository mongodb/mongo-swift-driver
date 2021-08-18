import Foundation
import MongoSwiftSync

/// Represents the events expected for the specified client.
struct ExpectedEventsForClient: Decodable {
    /// Client entity on which the events are expected to be observed.
    let client: String

    /// List of events, which are expected to be observed (in this order) on the corresponding client while executing
    /// operations. If the array is empty, the test runner MUST assert that no events were observed on the client
    /// (excluding ignored events).
    let events: [ExpectedEvent]
}

/// Describes expected events.
enum ExpectedEvent: Decodable {
    case commandStarted(CommandStartedExpectation)

    case commandSucceeded(CommandSucceededExpectation)

    case commandFailed(CommandFailedExpectation)

    private enum CodingKeys: String, CodingKey {
        case commandStartedEvent, commandSucceededEvent, commandFailedEvent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let started = try container.decodeIfPresent(CommandStartedExpectation.self, forKey: .commandStartedEvent) {
            self = .commandStarted(started)
        } else if let succeeded = try container.decodeIfPresent(
            CommandSucceededExpectation.self,
            forKey: .commandSucceededEvent
        ) {
            self = .commandSucceeded(succeeded)
        } else {
            let failed = try container.decode(CommandFailedExpectation.self, forKey: .commandFailedEvent)
            self = .commandFailed(failed)
        }
    }

    /// We use the below types rather than the driver's event types directly as we only care about making assertions
    /// for a subset of fields.
    /// Represents expectations for a CommandStartedEvent.
    struct CommandStartedExpectation: Decodable {
        ///  A value corresponding to the expected command document.
        let command: BSONDocument?

        /// Name of the command.
        let commandName: String?

        /// Name of the database the command is run against.
        let databaseName: String?

        /// Specifies whether the serviceId field of the event is set.
        let hasServiceId: Bool?
    }

    /// Represents expectations for a CommandSucceededEvent.
    struct CommandSucceededExpectation: Decodable {
        /// A value corresponding to the expected reply document.
        let reply: BSONDocument?

        /// Name of the command.
        let commandName: String?

        /// Specifies whether the serviceId field of the event is set.
        let hasServiceId: Bool?
    }

    /// Represents expectations for a CommandStartedEvent.
    struct CommandFailedExpectation: Decodable {
        /// Name of the command.
        let commandName: String?

        /// Specifies whether the serviceId field of the event is set.
        let hasServiceId: Bool?
    }
}
