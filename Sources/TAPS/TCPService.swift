// TCPService.swift
// RFC-compliant TCP service implementation
import Foundation

/// TCP service implementing ClientServiceProtocol
public struct TCPClientService: ClientServiceProtocol {
    public typealias Parameters = TCPParameters
    public typealias Client = TCPClient
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    /// Create TCP client with given parameters
    public func withConnection<T: Sendable>(
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await TCPClient.withConnection(
            host: host,
            port: port,
            parameters: parameters,
            perform: perform
        )
    }
}

/// TCP service parameters
public struct TCPParameters: ServiceParametersWithDefault {
    public var connectionTimeout: Duration
    public var keepAlive: Bool
    public var noDelay: Bool
    
    public init(
        connectionTimeout: Duration = .seconds(30),
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

extension ClientServiceProtocol where Self == TCPClientService {
    public static func tcp(host: String, port: Int) -> TCPClientService {
        TCPClientService(host: host, port: port)
    }
}
