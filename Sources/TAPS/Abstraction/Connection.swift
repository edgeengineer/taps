// Connection.swift
// Actor-based connection protocols

import AsyncAlgorithms
#if canImport(NIOCore)
internal import NIOCore
#endif

/// Base protocol for all connection types
public protocol ClientConnectionProtocol<InboundMessage, OutboundMessage>: Sendable {
    associatedtype InboundMessage: Sendable
    associatedtype OutboundMessage: Sendable
    associatedtype ConnectionError: Swift.Error
    
    func run() async throws
}

/// Protocol for server connections that accept clients
public protocol ServerConnectionProtocol<Client>: Sendable {
    associatedtype Client: ClientConnectionProtocol
    associatedtype ConnectionError: Error
    
    func withEachClient(
        _ acceptClient: @Sendable @escaping (Client) async throws(CancellationError) -> Void
    ) async throws(ConnectionError)
}

public struct ConnectionSubprotocol<
    InboundIn: Sendable,
    InboundOut: Sendable,
    OutboundIn: Sendable,
    OutboundOut: Sendable
> {
    #if canImport(NIOCore)
    let handlers: [any ChannelHandler]
    
    internal init(handlers: [any ChannelHandler]) {
        self.handlers = handlers
    }
    
    internal init(
        _ inboundIn: InboundIn.Type = InboundIn.self,
        _ inboundOut: OutboundOut.Type = OutboundOut.self,
        @ProtocolStackBuilder<InboundIn, OutboundOut> validated build: @escaping @Sendable () -> ProtocolStack<InboundIn, InboundOut, OutboundIn, OutboundOut>
    ) {
        self.handlers = build().handlers
    }
    #endif
}

public struct ProtocolStack<
    InboundIn: Sendable,
    InboundOut: Sendable,
    OutboundIn: Sendable,
    OutboundOut: Sendable
>: @unchecked Sendable {
    #if canImport(NIOCore)
    let handlers: [any ChannelHandler]
    #endif
    
    public init() {
        self.handlers = []
    }
    
    internal init(handlers: [any ChannelHandler]) {
        self.handlers = handlers
    }
    
    internal init(
        @ProtocolStackBuilder<InboundIn, OutboundOut> validated build: @escaping @Sendable () -> ProtocolStack<InboundIn, InboundOut, OutboundIn, OutboundOut>
    ) {
        self = build()
    }
}
