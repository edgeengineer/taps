//  Messages.swift
//  Generic message definitions and properties
//



/// Protocol for all message types - must be Sendable for Actor isolation
public protocol MessageProtocol: Sendable {
    associatedtype Content: Sendable
    associatedtype Properties: MessagePropertiesProtocol
    
    var content: Content { get }
    var properties: Properties { get }
}

/// Protocol for message properties - must be Sendable
public protocol MessagePropertiesProtocol: Sendable {
    var reliability: MessageReliability { get set }
    var priority: MessagePriority { get set }
    var deadline: ContinuousClock.Instant? { get set }
}

/// Message reliability levels
public enum MessageReliability: Sendable, CaseIterable {
    case reliable
    case unreliable
    case partial
}

/// Message priority levels
public enum MessagePriority: Sendable, CaseIterable {
    case background
    case normal
    case high
    case interactive
}
