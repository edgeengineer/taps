// Connection.swift
// Actor-based connection protocols

import AsyncAlgorithms

/// Base protocol for all connection types
public protocol ClientConnectionProtocol<InboundMessage, OutboundMessage>: Sendable {
    associatedtype InboundMessage: Sendable
    associatedtype OutboundMessage: Sendable
    associatedtype InboundStream: AsyncSequence where InboundStream.Element == InboundMessage
    associatedtype ConnectionError: Swift.Error
    
    var inbound: InboundStream { get }
}

/// Protocol for server connections that accept clients
public protocol ServerConnectionProtocol<Client>: Sendable {
    associatedtype Client: ClientConnectionProtocol
    associatedtype ConnectionError: Error
    
    func withEachClient(
        _ acceptClient: @Sendable @escaping (Client) async throws(CancellationError) -> Void
    ) async throws(ConnectionError)
}
