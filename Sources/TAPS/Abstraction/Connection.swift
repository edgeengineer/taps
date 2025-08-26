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
public protocol ClientConnectionProtocol<InboundMessage, OutboundMessage>: ConnectionProtocol {}

/// Protocol for server connections that accept clients
public protocol ServerConnectionProtocol: Sendable {
    associatedtype Client: ClientConnectionProtocol
    associatedtype ConnectionError: Swift.Error
    associatedtype Connections: AsyncSequence<Client, ConnectionError>
    
    /// Stream of accepted client connections
    var connections: Connections { get }
    
    /// Close the server and stop accepting connections
    func close() async throws
}
