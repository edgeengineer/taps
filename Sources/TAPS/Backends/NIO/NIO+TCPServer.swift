#if canImport(NIOPosix)
import AsyncAlgorithms
import NIOCore
import NIOPosix
import Logging

/// TCP Server with SwiftNIO implementation using structured concurrency
@available(macOS 15.0, *)
public actor TCPServer {
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tcp.server")
    
    /// Accept clients using withServer pattern with structured concurrency
    package static func withServer<T: Sendable>(
        port: Int,
        parameters: TCPServerParameters,
        acceptClient: @escaping @Sendable (TCPClient) async throws -> T
    ) async throws -> T {
        
        let logger = Logger(label: "engineer.edge.taps.tcp.server")
        logger.info("Starting TCP server", metadata: [
            "port": .stringConvertible(port),
            "backlog": .stringConvertible(parameters.backlog)
        ])
        
        // Bootstrap server with SwiftNIO following the same pattern as TCPClient
        let serverChannel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.backlog, value: Int32(parameters.backlog))
            .serverChannelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: parameters.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.socket(.init(IPPROTO_TCP), .init(TCP_NODELAY)), value: parameters.noDelay ? 1 : 0)
            .childChannelInitializer { channel in
                channel.eventLoop.makeSucceededVoidFuture()
            }
            .bind(host: "0.0.0.0", port: port)
            .get()
        
        logger.info("TCP server bound to port", metadata: ["port": .stringConvertible(port)])
        
        // Use withThrowingDiscardingTaskGroup for structured concurrency as requested
        return try await withThrowingDiscardingTaskGroup { group in
            
            // Server accepting task
            group.addTask {
                defer {
                    logger.info("TCP server shutting down")
                    Task {
                        try? await serverChannel.close().get()
                    }
                }
                
                // This is a placeholder - actual NIO server async implementation needed
                // For now, simulate server running
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                    // TODO: Implement real async server accept loop with SwiftNIO
                    // This requires proper NIOAsyncServerChannel support
                    
                    // Placeholder: create a mock client for testing
                    // In real implementation, this would be from serverChannel.accept()
                }
            }
            
            // Wait for cancellation - use a very long duration instead
            try await Task.sleep(for: .seconds(365 * 24 * 3600)) // 1 year
            return () as! T
        }
    }
}

#endif
