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
        
        // Create server channel
        let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .serverChannelOption(ChannelOptions.backlog, value: Int32(parameters.backlog))
            .childChannelOption(ChannelOptions.socket(.init(IPPROTO_TCP), .init(TCP_NODELAY)), value: parameters.noDelay ? 1 : 0)
            .bind(
                host: "0.0.0.0",
                port: port
            ) { channel in
                channel.eventLoop.makeCompletedFuture {
                    return try NIOAsyncChannel(
                        wrappingChannelSynchronously: channel,
                        configuration: NIOAsyncChannel.Configuration(
                            inboundType: ByteBuffer.self,
                            outboundType: ByteBuffer.self
                        )
                    )
                }
            }
        
        logger.info("TCP server bound to port", metadata: ["port": .stringConvertible(port)])
        
        // Handle connections using withThrowingDiscardingTaskGroup
        return try await withThrowingDiscardingTaskGroup { group in
            try await channel.executeThenClose { inbound in
                for try await connectionChannel in inbound {
                    logger.info("TCP server accepted new client connection")
                    return try await handleConnection(channel: connectionChannel, acceptClient: acceptClient, logger: logger)
                }
                throw TAPSError.serviceUnavailable("No clients connected")
            }
        }
    }
    
    /// Handle a single connection using ByteBuffer-based NIOAsyncChannel
    private static func handleConnection<T: Sendable>(
        channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>,
        acceptClient: @escaping @Sendable (TCPClient) async throws -> T,
        logger: Logger
    ) async throws -> T {
        return try await channel.executeThenClose { inbound, outbound in
            logger.info("TCP server creating TCPClient with ByteBuffer streams")
            let client = TCPClient(inbound: inbound, outbound: outbound)
            return try await acceptClient(client)
        }
    }
}


#endif
