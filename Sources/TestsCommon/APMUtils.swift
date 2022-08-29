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
        self.enable()
        defer { self.disable() }
        return try f()
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
         poolCreatedEvent, poolReadyEvent, poolClearedEvent, poolClosedEvent,
         topologyDescriptionChanged, topologyOpening, topologyClosed, serverDescriptionChanged,
         serverOpening, serverClosed, serverHeartbeatStarted, serverHeartbeatSucceeded,
         serverHeartbeatFailed
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

extension SDAMEvent {
    public var type: EventType {
        switch self {
        case .topologyDescriptionChanged:
            return .topologyDescriptionChanged
        case .topologyOpening:
            return .topologyOpening
        case .topologyClosed:
            return .topologyClosed
        case .serverDescriptionChanged:
            return .serverDescriptionChanged
        case .serverOpening:
            return .serverOpening
        case .serverClosed:
            return .serverClosed
        case .serverHeartbeatStarted:
            return .serverHeartbeatStarted
        case .serverHeartbeatSucceeded:
            return .serverHeartbeatSucceeded
        case .serverHeartbeatFailed:
            return .serverHeartbeatFailed
        }
    }

    // Failable accessors for the different types of topology events.

    /// Returns this event as a `TopologyOpeningEvent` if it is one, nil otherwise.
    public var topologyOpeningValue: TopologyOpeningEvent? {
        guard case let .topologyOpening(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `TopologyClosedEvent` if it is one, nil otherwise.
    public var topologyClosedValue: TopologyClosedEvent? {
        guard case let .topologyClosed(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `TopologyDescriptionChangedEvent` if it is one, nil otherwise.
    public var topologyDescriptionChangedValue: TopologyDescriptionChangedEvent? {
        guard case let .topologyDescriptionChanged(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerOpeningEvent` if it is one, nil otherwise.
    public var serverOpeningValue: ServerOpeningEvent? {
        guard case let .serverOpening(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerClosedEvent` if it is one, nil otherwise.
    public var serverClosedValue: ServerClosedEvent? {
        guard case let .serverClosed(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerDescriptionChangedEvent` if it is one, nil otherwise.
    public var serverDescriptionChangedValue: ServerDescriptionChangedEvent? {
        guard case let .serverDescriptionChanged(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerHeartbeatStartedEvent` if it is one, nil otherwise.
    public var serverHeartbeatStartedValue: ServerHeartbeatStartedEvent? {
        guard case let .serverHeartbeatStarted(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerHeartbeatSucceededEvent` if it is one, nil otherwise.
    public var serverHeartbeatSucceededValue: ServerHeartbeatSucceededEvent? {
        guard case let .serverHeartbeatSucceeded(event) = self else {
            return nil
        }
        return event
    }

    /// Returns this event as a `ServerHeartbeatFailedEvent` if it is one, nil otherwise.
    public var serverHeartbeatFailedValue: ServerHeartbeatFailedEvent? {
        guard case let .serverHeartbeatFailed(event) = self else {
            return nil
        }
        return event
    }

    /// Checks whether or not this event is a `ServerHeartbeatStartedEvent`, `ServerHeartbeatSucceededEvent`, or
    /// a `ServerHeartbeatFailedEvent`.
    public var isHeartbeatEvent: Bool {
        switch self {
        case .serverHeartbeatFailed, .serverHeartbeatStarted, .serverHeartbeatSucceeded:
            return true
        default:
            return false
        }
    }
}
