// ServiceProtocols.swift
// RFC-compliant service protocols

import AsyncAlgorithms

/// Base protocol for all transport services
public protocol ServiceProtocol: Sendable {
    associatedtype Parameters: ServiceParameters
}

/// Base protocol for client services
public protocol ClientServiceProtocol: ServiceProtocol where Parameters: ClientServiceParameters {
    associatedtype Client: ClientConnectionProtocol
    
    /// Create connection with given parameters and context
    func withConnection<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T
}

/// Base protocol for server services
public protocol ServerServiceProtocol: ServiceProtocol where Parameters: ServerServiceParameters {
    associatedtype Client: ClientConnectionProtocol
    
    /// Accept clients using withServer pattern
    func withServer<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        acceptClient: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T
}


