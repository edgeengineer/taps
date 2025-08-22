// Message.swift
// Actor-compatible message protocols

import Foundation

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

/// Simple TCP message implementation using Array<UInt8>
public struct TCPMessage: MessageProtocol {
    public typealias Content = Array<UInt8>
    public typealias Properties = BasicMessageProperties
    
    public let content: Array<UInt8>
    public let properties: BasicMessageProperties
    
    public init(content: Array<UInt8>, properties: BasicMessageProperties = .default) {
        self.content = content
        self.properties = properties
    }
    
    /// Convenience initializer for string content
    public init(_ string: String, properties: BasicMessageProperties = .default) {
        self.content = Array(string.utf8)
        self.properties = properties
    }
}

/// Basic message properties implementation
public struct BasicMessageProperties: MessagePropertiesProtocol {
    public var reliability: MessageReliability = .reliable
    public var priority: MessagePriority = .normal
    public var deadline: ContinuousClock.Instant? = nil
    
    public init(
        reliability: MessageReliability = .reliable,
        priority: MessagePriority = .normal,
        deadline: ContinuousClock.Instant? = nil
    ) {
        self.reliability = reliability
        self.priority = priority
        self.deadline = deadline
    }
    
    public static let `default` = BasicMessageProperties()
}