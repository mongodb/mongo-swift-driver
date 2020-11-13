import Foundation
import MongoSwift

/// A command event handler that caches the events it encounters.
/// Note: it will only cache events that occur while closures passed to `captureEvents` are executing.
public class TestCommandMonitor: CommandEventHandler {
    private var monitoring: Bool
    private var events: [CommandEvent]

    public init() {
        self.events = []
        self.monitoring = false
    }

    public func handleCommandEvent(_ event: CommandEvent) {
        guard self.monitoring else {
            return
        }
        self.events.append(event)
    }

    /// Retrieve all the command started events seen so far, clearing the event cache.
    public func commandStartedEvents(withNames namesFilter: [String]? = nil) -> [CommandStartedEvent] {
        self.events(withNames: namesFilter).compactMap(\.commandStartedValue)
    }

    /// Retrieve all the command started events seen so far, clearing the event cache.
    public func commandSucceededEvents(withNames namesFilter: [String]? = nil) -> [CommandSucceededEvent] {
        self.events(withNames: namesFilter).compactMap(\.commandSucceededValue)
    }

    /// Retrieve all the events seen so far that match the optionally provided filters, clearing the event cache.
    public func events(
        withEventTypes typeFilter: [CommandEvent.EventType]? = nil,
        withNames nameFilter: [String]? = nil
    ) -> [CommandEvent] {
        defer { self.events.removeAll() }
        return self.events.compactMap { event in
            if let typeFilter = typeFilter {
                guard typeFilter.contains(event.type) else {
                    return nil
                }
            }
            if let nameFilter = nameFilter {
                guard nameFilter.contains(event.commandName) else {
                    return nil
                }
            }
            return event
        }
    }

    /// Capture events that occur while the the provided closure executes.
    public func captureEvents<T>(_ f: () throws -> T) rethrows -> T {
        self.monitoring = true
        defer { self.monitoring = false }
        return try f()
    }
}

extension CommandEvent {
    public enum EventType {
        case commandStarted
        case commandSucceeded
        case commandFailed
    }

    /// The "type" of this event. Used for filtering events by their type.
    public var type: EventType {
        switch self {
        case .started:
            return .commandStarted
        case .failed:
            return .commandFailed
        case .succeeded:
            return .commandSucceeded
        }
    }

    /// Returns this event as a `CommandStartedEvent` if it is one, nil otherwise.
    public var commandStartedValue: CommandStartedEvent? {
        guard case let .started(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `CommandSucceededEvent` if it is one, nil otherwise.
    public var commandSucceededValue: CommandSucceededEvent? {
        guard case let .succeeded(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `CommandFailedEvent` if it is one, nil otherwise.
    public var commandFailedValue: CommandFailedEvent? {
        guard case let .failed(event) = self else {
            return nil
        }
        return event
    }
}
