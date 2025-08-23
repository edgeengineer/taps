// ServiceProtocols.swift
// RFC-compliant service protocols

import AsyncAlgorithms

/// Base protocol for client services
public protocol ClientServiceProtocol: Sendable {
    associatedtype Parameters: Sendable
    associatedtype Client: ClientConnection
    
    /// Create connection with given parameters
    func withConnection<T: Sendable>(
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
    associatedtype Server: ServerConnectionProtocol
    
    /// Create server with given parameters
    func makeServer(parameters: Parameters) async throws -> Server
}

/// Server parameters with defaults
public protocol ServerServiceParametersWithDefault: Sendable {
    static var defaultParameters: Self { get }
}

#if canImport(NIOCore)
import NIOCore
public typealias NetworkBytes = ByteBuffer
#elseif canImport(Network)
import Foundation
public typealias NetworkBytes = Data
#endif
