import Foundation
import MongoSwift
import NIOConcurrencyHelpers

/// A command event handler that caches the events it encounters.
/// Note: it will only cache events that occur while closures passed to `captureEvents` are executing.
public class TestCommandMonitor: CommandEventHandler {
    private var monitoring: Bool
    private var events: [CommandEvent]
    // Lock over monitoring and events.
    private var lock: Lock

    public init() {
        self.events = []
        self.monitoring = false
        self.lock = Lock()
    }

    public func handleCommandEvent(_ event: CommandEvent) {
        self.lock.withLock {
            guard self.monitoring else {
                return
            }
            self.events.append(event)
        }
    }

    /// Retrieve all the command started events seen so far, clearing the event cache.
    public func commandStartedEvents(withNames namesFilter: [String]? = nil) -> [CommandStartedEvent] {
        self.events(withNames: namesFilter).compactMap { $0.commandStartedValue }
    }

    /// Retrieve all the command started events seen so far, clearing the event cache.
    public func commandSucceededEvents(withNames namesFilter: [String]? = nil) -> [CommandSucceededEvent] {
        self.events(withNames: namesFilter).compactMap { $0.commandSucceededValue }
    }

    /// Retrieve all the events seen so far that match the optionally provided filters, clearing the event cache.
    public func events(
        withEventTypes typeFilter: [EventType]? = nil,
        withNames nameFilter: [String]? = nil
    ) -> [CommandEvent] {
        self.lock.withLock {
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
    }

    /// Capture events that occur while the the provided closure executes.
    public func captureEvents<T>(_ f: () throws -> T) rethrows -> T {
        try self.lock.withLock {
            self.monitoring = true
            defer { self.monitoring = false }
            return try f()
        }
    }

    /// Enable monitoring, if it is not enabled already.
    public func enable() {
        self.lock.withLock {
            self.monitoring = true
        }
    }

    /// Disable monitoring, if it is not disabled already.
    public func disable() {
        self.lock.withLock {
            self.monitoring = false
        }
    }
}

public enum EventType: String, Decodable {
    case commandStartedEvent, commandSucceededEvent, commandFailedEvent,
         connectionCreatedEvent, connectionReadyEvent, connectionClosedEvent,
         connectionCheckedInEvent, connectionCheckedOutEvent, connectionCheckOutFailedEvent,
         poolCreatedEvent, poolReadyEvent, poolClearedEvent, poolClosedEvent
}

extension CommandEvent {
    public var type: EventType {
        switch self {
        case .started:
            return .commandStartedEvent
        case .failed:
            return .commandFailedEvent
        case .succeeded:
            return .commandSucceededEvent
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
