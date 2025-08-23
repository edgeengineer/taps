// Connection.swift
// Actor-based connection protocols

import AsyncAlgorithms

/// Base protocol for all connection types with state management
public protocol ConnectionProtocol<InboundMessage, OutboundMessage>: Sendable {
    associatedtype InboundMessage: Sendable
    associatedtype OutboundMessage: Sendable
    associatedtype ConnectionError: Swift.Error
    associatedtype Inbound: AsyncSequence<InboundMessage, ConnectionError>
    
    /// Stream of connection events
    var inbound: Inbound { get }
}

/// Protocol for client connections
public protocol ClientConnection<InboundMessage, OutboundMessage>: ConnectionProtocol {}

/// Protocol for server connections that accept clients
public protocol ServerConnectionProtocol<
    InboundMessage,
    OutboundMessage
>: ConnectionProtocol where
    OutboundMessage == Never,
    InboundMessage: ClientConnection<InboundMessage, OutboundMessage>
{
    
}
