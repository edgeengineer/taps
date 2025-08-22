// Connection.swift
// Actor-based connection protocols

import AsyncAlgorithms

/// Connection state - fully Sendable
public enum ConnectionState: Sendable, Equatable {
    case establishing
    case ready
    case closing
    case closed
    case failed(String)
    
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.establishing, .establishing),
             (.ready, .ready),
             (.closing, .closing),
             (.closed, .closed):
            return true
        case (.failed(let lhsMsg), .failed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// Connection events - fully Sendable
public enum ConnectionEvent: Sendable {
    case ready
    case pathChanged(PathInfo)
    case closed
    case failed(String)
}

/// Path information for connection events
public struct PathInfo: Sendable {
    public let localEndpoint: String
    public let remoteEndpoint: String
    public let interface: String?
}


/// Base protocol for all connection types with state management
public protocol ConnectionProtocol: Sendable {
    associatedtype InboundMessage: MessageProtocol
    associatedtype OutboundMessage: MessageProtocol
    
    /// Current connection state
    var state: ConnectionState { get async }
    
    /// Stream of connection events
    var events: AsyncChannel<ConnectionEvent> { get async }
    
    /// Close the connection
    func close() async throws
}

/// Protocol for client connections
public protocol ClientConnectionProtocol: ConnectionProtocol {
    /// Send a message
    func send(_ message: OutboundMessage) async throws
    
    /// Stream of received messages
    var received: AsyncChannel<InboundMessage> { get async }
}

/// Protocol for server connections that accept clients
public protocol ServerConnectionProtocol: ConnectionProtocol {
    associatedtype AcceptedConnection: ClientConnectionProtocol
    
    /// Stream of accepted client connections
    var connections: AsyncChannel<AcceptedConnection> { get }
}


/// Endpoint identifier
public struct EndpointIdentifier: Sendable, Hashable {
    public let host: String
    public let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}
