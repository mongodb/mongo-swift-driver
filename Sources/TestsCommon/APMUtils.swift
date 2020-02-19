import Foundation
import MongoSwift

public class TestCommandEventHandler: CommandEventHandler {
    private let eventTypes: [CommandEventType]?
    private let commandNames: [String]?
    private var monitoring: Bool

    public var events: [CommandEvent]

    public init(eventTypes: [CommandEventType]? = nil, commandNames: [String]? = nil) {
        self.eventTypes = eventTypes
        self.commandNames = commandNames
        self.events = []
        self.monitoring = false
    }

    public func beginMonitoring() {
        self.monitoring = true
    }

    public func stopMonitoring() {
        self.monitoring = false
    }

    public func handleCommandEvent(_ event: CommandEvent) {
        guard self.monitoring else {
            return
        }

        if let typeWhitelist = self.eventTypes {
            switch event {
            case .started:
                guard typeWhitelist.contains(.commandStarted) else {
                    return
                }
            case .failed:
                guard typeWhitelist.contains(.commandFailed) else {
                    return
                }

            case .succeeded:
                guard typeWhitelist.contains(.commandSucceeded) else {
                    return
                }
            }
        }

        if let nameWhitelist = self.commandNames {
            guard nameWhitelist.contains(event.commandName) else {
                return
            }
        }

        self.events.append(event)
    }

    public func commandStartedEvents(withNames nameFilter: [String]? = nil) -> [CommandStartedEvent] {
        return self.events.compactMap { event in
            guard case let .started(event) = event else {
                return nil
            }
            if let nameFilter = nameFilter {
                guard nameFilter.contains(event.commandName) else {
                    return nil
                }
            }
            return event
        }
    }

    public func commandSucceededEvents(withNames nameFilter: [String]? = nil) -> [CommandSucceededEvent] {
        return self.events.compactMap { event in
            guard case let .succeeded(event) = event else {
                return nil
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

public enum CommandEventType {
    case commandStarted
    case commandSucceeded
    case commandFailed
}

extension CommandEvent {
    public var eventType: CommandEventType {
        switch self {
        case .started:
            return .commandStarted
        case .failed:
            return .commandFailed
        case .succeeded:
            return .commandSucceeded
        }
    }

    public var commandStartedValue: CommandStartedEvent? {
        guard case let .started(event) = self else {
            return nil
        }
        return event
    }

    public var commandSucceededValue: CommandSucceededEvent? {
        guard case let .succeeded(event) = self else {
            return nil
        }
        return event
    }

    public var commandFailedValue: CommandFailedEvent? {
        guard case let .failed(event) = self else {
            return nil
        }
        return event
    }
}
