#if canImport(NIOPosix)
import AsyncAlgorithms
internal import NIOCore
internal import NIOPosix
import Logging

public struct TCPServer<
    InboundMessage: Sendable,
    OutboundMessage: Sendable
>: ServerConnectionProtocol {
    public typealias Client = TCPSocket<InboundMessage, OutboundMessage>
    public typealias ConnectionError = any Error

    private nonisolated let inbound: NIOAsyncChannelInboundStream<NIOAsyncChannel<InboundMessage, OutboundMessage>>

    private init(inbound: NIOAsyncChannelInboundStream<NIOAsyncChannel<InboundMessage, OutboundMessage>>) {
        self.inbound = inbound
    }

    internal static func withServer<T: Sendable>(
        host: String,
        port: Int,
        parameters: TCPServerParameters,
        context: TAPSContext,
        protocolStack: ProtocolStack<_NetworkInputBytes, InboundMessage, OutboundMessage, _NetworkOutputBytes> = ProtocolStack(),
        perform: @escaping @Sendable (TCPServer) async throws -> T
    ) async throws -> T {
        let server = try await ServerBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .serverChannelOption(.backlog, value: parameters.backlog)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 1)
            .childChannelInitializer { channel in
                do {
                    try channel.pipeline.syncOperations.addHandlers(protocolStack.handlers())
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
            .bind(host: host, port: port) { client in
                return client.eventLoop.submit {
                    try NIOAsyncChannel<
                        InboundMessage,
                        OutboundMessage
                    >(wrappingChannelSynchronously: client)
                }
            }

        return try await server.executeThenClose { inbound in
            return try await perform(TCPServer(inbound: inbound))
        }
    }
    
    public nonisolated func withEachClient(
        _ acceptClient: @Sendable @escaping (Client) async throws(CancellationError) -> Void
    ) async throws(ConnectionError) {
        try await withThrowingDiscardingTaskGroup { group in
            for try await client in inbound {
                group.addTask {
                    return try await client.executeThenClose { inbound, outbound in
                        let socket = TCPSocket(inbound: inbound, outbound: outbound)
                        return try await acceptClient(socket)
                    }
                }
            }
        }
    }
}

/// TCP Client as proper with real SwiftNIO implementation
@available(macOS 15.0, *)
public struct TCPSocket<
    InboundMessage: Sendable,
    OutboundMessage: Sendable
>: ClientConnectionProtocol {
    public typealias ConnectionError = any Error
    
    // Actor-isolated state
    internal nonisolated let _inbound: NIOAsyncChannelInboundStream<InboundMessage>
    internal nonisolated let outbound: NIOAsyncChannelOutboundWriter<OutboundMessage>
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tcp")
    
    public nonisolated var inbound: some AsyncSequence<InboundMessage, ConnectionError> {
        _inbound
    }
    
    /// Initialize TCP client with endpoint and parameters
    internal init(
        inbound: NIOAsyncChannelInboundStream<InboundMessage>,
        outbound: NIOAsyncChannelOutboundWriter<OutboundMessage>
    ) {
        self._inbound = inbound
        self.outbound = outbound
    }
    
    public func run() async throws {
        // TODO: Do we need to keep `run()` active in the background?
    }
    
    internal static func withClientConnection<T: Sendable>(
        host: String,
        port: Int,
        parameters: TCPClientParameters,
        context: TAPSContext,
        protocolStack: ProtocolStack<ByteBuffer, InboundMessage, OutboundMessage, IOData> = ProtocolStack(),
        perform: @escaping @Sendable (TCPSocket<InboundMessage, OutboundMessage>) async throws -> T
    ) async throws -> T {
        // Bootstrap TCP connection with simpler pipeline
        let channel = try await ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .applyParameters(parameters)
            .channelInitializer { [protocolStack] channel in
                do {
                    try channel.pipeline.syncOperations.addHandlers(protocolStack.handlers())
                    return channel.eventLoop.makeSucceededVoidFuture()
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
            .connect(host: host, port: port)
            .flatMapThrowing { channel in
                try NIOAsyncChannel<InboundMessage, OutboundMessage>(wrappingChannelSynchronously: channel)
            }
            .get()
        
        return try await channel.executeThenClose {
            inbound,
            outbound in
            return try await perform(
                TCPSocket(
                    inbound: inbound,
                    outbound: outbound
                )
            )
        }
    }
    
    public func send(_ message: OutboundMessage) async throws {
        try await outbound.write(message)
    }
}
#endif
