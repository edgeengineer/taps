// TCPServerService.swift
// RFC-compliant TCP server service implementation

import Foundation

/// TCP server service implementing ServerServiceProtocol
@available(macOS 15.0, *)
public actor TCPServerService: ServerServiceProtocol {
    public typealias Parameters = TCPServerParameters
    public typealias Client = TCPClient
    
    private let port: Int
    
    public init(port: Int) {
        self.port = port
    }
    
    /// Accept clients using withServer pattern with structured concurrency
    public func withServer<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        acceptClient: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await TCPServer.withServer(
            port: port,
            parameters: parameters,
            acceptClient: acceptClient
        )
    }
}

extension ServerServiceProtocol where Self == TCPServerService {
    public static func tcp(port: Int) -> TCPServerService {
        TCPServerService(port: port)
    }
}

/// TCP server service parameters
public struct TCPServerParameters: ServerServiceParametersWithDefault {
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var keepAlive: Bool
    public var noDelay: Bool
    
    public init(
        port: Int,
        backlog: Int = 128,
        reuseAddress: Bool = true,
        keepAlive: Bool = false,
        noDelay: Bool = true
    ) {
        self.port = port
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.keepAlive = keepAlive
        self.noDelay = noDelay
    }
    
    public static var defaultParameters: TCPServerParameters {
        return TCPServerParameters(port: 0)
    }
}
