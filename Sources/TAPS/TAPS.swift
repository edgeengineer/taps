// TAPS.swift

import Logging

@available(macOS 15.0, *)
public actor TAPS {
    private let logger = Logger(label: "engineer.edge.taps.main")
    
    /// Initialize TAPS instance
    public init() {}
    
    /// Run TAPS as a service
    public func run() async throws {
        // Service event loop
        while true {
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    
    /// Generic withConnection method with default parameters
    public func withConnection<Service: ClientServiceProtocol, T: Sendable>(
        to service: Service,
        _ operation: @Sendable @escaping (Service.Client) async throws -> T
    ) async throws -> T where Service.Parameters: ParametersWithDefault {
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
            context: TAPSContext()
        ) { client in
            try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                taskGroup.addTask {
                    try await client.run()
                }
                
                defer { taskGroup.cancelAll() }
                return try await operation(client)
            }
        }
    }
    
    // MARK: - Server Support

    public nonisolated func withServer<Service: ServerServiceProtocol>(
        on service: Service,
        acceptClient: @Sendable @escaping (Service.Server.Client) async throws -> Void
    ) async throws where Service.Parameters: ParametersWithDefault {
        try await withServer(
            on: service,
            parameters: Service.Parameters.defaultParameters,
            acceptClient: acceptClient
        )
    }
    
    public nonisolated func withServer<Service: ServerServiceProtocol>(
        on service: Service,
        parameters: Service.Parameters,
        acceptClient: @escaping @Sendable (sending Service.Server.Client) async throws -> Void
    ) async throws {
        try await service.withServer(
            parameters: parameters,
            context: TAPSContext()
        ) { server in
            try await server.withEachClient { client throws(CancellationError) in
                do {
                    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                        taskGroup.addTask {
                            try await client.run()
                        }
                        
                        defer { taskGroup.cancelAll() }
                        return try await acceptClient(client)
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    self.logger.debug("Inbound connection closed unexpectedly")
                }
            }
        }
    }
}
