// ServiceProtocols.swift
// RFC-compliant service protocols

import AsyncAlgorithms

/// Base protocol for client services
public protocol ClientServiceProtocol: Sendable {
    associatedtype Parameters: Sendable
    associatedtype Client: ClientConnectionProtocol
    
    /// Create connection with given parameters and context
    func withConnection<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T
}

/// Parameters with default values
public protocol ServiceParametersWithDefault: Sendable {
    static var defaultParameters: Self { get }
}

/// Base protocol for server services
public protocol ServerServiceProtocol: Sendable {
    associatedtype Parameters: Sendable
    associatedtype Client: ClientConnectionProtocol
    
    /// Accept clients using withServer pattern
    func withServer<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        acceptClient: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T
}

/// Server parameters with defaults
public protocol ServerServiceParametersWithDefault: Sendable {
    static var defaultParameters: Self { get }
}


