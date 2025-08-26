// TCPClientService.swift
// RFC-compliant TCP service implementation
import Foundation

/// TCP service implementing ClientServiceProtocol
public struct TCPClientService: ClientServiceProtocol {
    public typealias Parameters = TCPClientParameters
    public typealias Client = TCPClient
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    /// Create TCP client with given parameters and context
    public func withConnection<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await TCPClient.withConnection(
            context: context,
            host: host,
            port: port,
            parameters: parameters,
            perform: perform
        )
    }
}

extension ClientServiceProtocol where Self == TCPClientService {
    public static func tcp(host: String, port: Int) -> TCPClientService {
        TCPClientService(host: host, port: port)
    }
}

/// TCP Client service parameters
public struct TCPClientParameters: ServiceParametersWithDefault {
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
    
    public static var defaultParameters: TCPClientParameters {
        return TCPClientParameters()
    }
}
