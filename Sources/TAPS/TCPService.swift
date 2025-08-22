// TCPService.swift
// RFC-compliant TCP service implementation
import Foundation

/// TCP service implementing ClientServiceProtocol
public struct TCPService: ClientServiceProtocol {
    public typealias Parameters = TCPParameters
    public typealias Client = TCPClient
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    /// Create TCP client with given parameters
    public func makeClient(parameters: TCPParameters) async throws -> TCPClient {
        let endpoint = EndpointIdentifier(host: host, port: port)
        let client = TCPClient(endpoint: endpoint, parameters: parameters)
        try await client.connect()
        return client
    }
}

/// TCP service parameters
public struct TCPParameters: ServiceParametersWithDefault {
    public var connectionTimeout: TimeInterval
    public var keepAlive: Bool
    public var noDelay: Bool
    
    public init(
        connectionTimeout: TimeInterval = 30.0,
        keepAlive: Bool = false,
        noDelay: Bool = true
    ) {
        self.connectionTimeout = connectionTimeout
        self.keepAlive = keepAlive
        self.noDelay = noDelay
    }
    
    public static var defaultParameters: TCPParameters {
        return TCPParameters()
    }
}
