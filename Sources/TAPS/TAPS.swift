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
    
    // MARK: - Client Support
    
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
        // TAPS creates an empty TAPSContext for each connection
        let context = TAPSContext()
        
        return try await service.withConnection(
            context: context,
            parameters: parameters,
            perform: operation
        )
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

extension TAPS {
    
    // MARK: - Server Support
    /// Generic withServer method with default parameters
    public func withServer<Service: ServerServiceProtocol, T: Sendable>(
        context: TAPSContext,
        on service: Service,
        acceptClient: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T where Service.Parameters: ServerServiceParametersWithDefault {
        return try await withServer(
            context: context,
            on: service,
            parameters: Service.Parameters.defaultParameters,
            acceptClient: acceptClient
        )
    }
    
    @_disfavoredOverload
    /// Generic withServer method with explicit parameters
    public func withServer<Service: ServerServiceProtocol, T: Sendable>(
        context: TAPSContext,
        on service: Service,
        parameters: Service.Parameters,
        acceptClient: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T {
        return try await service.withServer(
            context: context,
            parameters: parameters,
            acceptClient: acceptClient
        )
    }
    
}
