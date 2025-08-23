// TAPS.swift
// Main TAPS Actor with RFC-compliant API

import Logging

@available(macOS 15.0, *)
public actor TAPS: ServiceDiscovery {
    
    // Internal state - protected by Actor isolation
    private var activeConnections: Set<String> = []
    private var connectionCounter: Int = 0
    private var isRunning: Bool = false
    private let logger: Logger
    
    /// Initialize TAPS instance
    public init() {
        self.logger = Logger(label: "engineer.edge.taps.main")
        logger.info("TAPS service initialized")
    }
    
    /// Run TAPS as a service (required by RFC)
    public func run() async throws {
        precondition(!isRunning, "TAPS service already running")
        logger.info("Starting TAPS service")
        isRunning = true
        defer { shutdown() }
        
        // Service event loop
        while isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    /// Generic withConnection method with default parameters
    public func withConnection<Service: ClientServiceProtocol, T: Sendable>(
        to service: Service,
        _ operation: @Sendable @escaping (Service.Client) async throws -> T
    ) async throws -> T where Service.Parameters: ServiceParametersWithDefault {
        return try await withConnection(
            to: service,
            parameters: Service.Parameters.defaultParameters,
            operation
        )
    }
    
    /// Generic withConnection method with explicit parameters
    public func withConnection<Service: ClientServiceProtocol, T: Sendable>(
        to service: Service,
        parameters: Service.Parameters,
        _ operation: @Sendable @escaping (Service.Client) async throws -> T
    ) async throws -> T {
        return try await service.withConnection(
            parameters: parameters,
            perform: operation
        )
    }
    
    // MARK: - Server Support (future)
    
    /// Generic withServer method (placeholder for future implementation)
    public func withServer<Service: ServerServiceProtocol, T: Sendable>(
        on service: Service,
        parameters: Service.Parameters,
        acceptClient: @Sendable @escaping (Service.Server) async throws -> T
    ) async throws -> T where Service.Parameters: ServerServiceParametersWithDefault {
        // Future implementation for server support
        throw TAPSError.serviceUnavailable("Server support not implemented yet")
    }
    
    // MARK: - Private Actor Methods
    
    private func trackConnection() -> String {
        connectionCounter += 1
        let connectionId = "conn_\(connectionCounter)"
        activeConnections.insert(connectionId)
        logger.debug("Connection tracked", metadata: [
            "connectionId": .string(connectionId),
            "totalConnections": .stringConvertible(activeConnections.count)
        ])
        return connectionId
    }
    
    private func removeConnection(_ id: String) {
        activeConnections.remove(id)
        logger.debug("Connection removed", metadata: [
            "connectionId": .string(id),
            "totalConnections": .stringConvertible(activeConnections.count)
        ])
    }
    
    private func shutdown() {
        logger.info("TAPS service shutting down")
        isRunning = false
        activeConnections.removeAll()
    }
    
    /// Get current connection count (for debugging)
    public var connectionCount: Int {
        activeConnections.count
    }
}
