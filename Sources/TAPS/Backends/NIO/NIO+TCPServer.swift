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
            
            // Create async sequence for server accepts
            let serverSequence = AsyncServerSequence(serverChannel: serverChannel, logger: logger)
            
            // Server accepting task - handle all client connections
            group.addTask { @Sendable in
                do {
                    // Accept connections and handle each client
                    for try await clientChannel in serverSequence {
                        // Create a new task group for each client to avoid capturing 'group'
                        Task { @Sendable in
                            do {
                                let asyncClientChannel = try NIOAsyncChannel<ByteBuffer, ByteBuffer>(
                                    wrappingChannelSynchronously: clientChannel
                                )
                                
                                try await asyncClientChannel.executeThenClose { inbound, outbound in
                                    let client = TCPClient(inbound: inbound, outbound: outbound)
                                    _ = try await acceptClient(client)
                                }
                            } catch {
                                logger.error("Error handling client", metadata: [
                                    "error": .string(String(describing: error))
                                ])
                            }
                        }
                    }
                } catch {
                    logger.error("Server accept loop failed", metadata: [
                        "error": .string(String(describing: error))
                    ])
                }
            }
            
            // The server runs until cancelled - this will complete when TaskGroup is cancelled
            try await Task.sleep(until: .now.advanced(by: .seconds(365 * 24 * 3600)), clock: .continuous)
            return () as! T
        }
    }
}

// MARK: - AsyncServerSequence

/// Simplified async sequence for TCP server (placeholder implementation)
/// 
/// NOTE: This is a simplified implementation. A production-ready version would require
/// deeper integration with NIO's ServerBootstrap and EventLoop mechanisms.
@available(macOS 15.0, *)
internal struct AsyncServerSequence: AsyncSequence {
    typealias Element = Channel
    
    private let serverChannel: Channel
    private let logger: Logger
    
    init(serverChannel: Channel, logger: Logger) {
        self.serverChannel = serverChannel
        self.logger = logger
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(serverChannel: serverChannel, logger: logger)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        private let serverChannel: Channel
        private let logger: Logger
        private var isFinished = false
        
        init(serverChannel: Channel, logger: Logger) {
            self.serverChannel = serverChannel
            self.logger = logger
        }
        
        mutating func next() async throws -> Channel? {
            // This is a placeholder implementation
            // In a real implementation, this would integrate with NIO's server accept mechanism
            
            guard !isFinished else { return nil }
            
            logger.debug("TCP server async sequence - placeholder implementation")
            
            // For now, this will never actually accept connections
            // Real implementation would need NIO ServerBootstrap with async support
            isFinished = true
            
            throw TAPSError.serviceUnavailable("TCP Server async accept not yet fully implemented. Requires deeper NIO integration.")
        }
    }
}

#endif
