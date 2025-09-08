#if canImport(NIOPosix)
import AsyncAlgorithms
internal import NIOCore
internal import NIOPosix
import Logging

public struct TCPServer: ServerConnectionProtocol {
    public typealias Client = TCPSocket
    public typealias ConnectionError = any Error

    private nonisolated let inbound: NIOAsyncChannelInboundStream<NIOAsyncChannel<ByteBuffer, ByteBuffer>>

    private init(inbound: NIOAsyncChannelInboundStream<NIOAsyncChannel<ByteBuffer, ByteBuffer>>) {
        self.inbound = inbound
    }

    package static func withServer<T: Sendable>(
        host: String,
        port: Int,
        parameters: TCPServerParameters,
        context: TAPSContext,
        perform: @escaping @Sendable (TCPServer) async throws -> T
    ) async throws -> T {
        let server = try await ServerBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .serverChannelOption(.backlog, value: parameters.backlog)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 1)
            .bind(host: host, port: port) { client in
                return client.eventLoop.submit {
                    try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: client)
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
public struct TCPSocket: ClientConnectionProtocol {
    public typealias InboundMessage = NetworkInputBytes
    public typealias OutboundMessage = NetworkOutputBytes
    public typealias ConnectionError = any Error
    
    // Actor-isolated state
    private nonisolated let _inbound: NIOAsyncChannelInboundStream<ByteBuffer>
    private nonisolated let outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tcp")
    
    public nonisolated var inbound: some AsyncSequence<InboundMessage, ConnectionError> {
        _inbound.map { buffer in
            NetworkInputBytes(buffer: buffer)
        }
    }
    
    /// Initialize TCP client with endpoint and parameters
    internal init(
        inbound: NIOAsyncChannelInboundStream<ByteBuffer>,
        outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>
    ) {
        self._inbound = inbound
        self.outbound = outbound
    }
    
    public func run() async throws {
        // TODO: Do we need to keep `run()` active in the background?
    }

    package static func withClientConnection<T: Sendable>(
        host: String,
        port: Int,
        parameters: TCPClientParameters,
        context: TAPSContext,
        perform: @escaping @Sendable (TCPSocket) async throws -> T
    ) async throws -> T {
        // Bootstrap TCP connection with simpler pipeline
        let channel = try await ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .applyParameters(parameters)
            .connect(host: host, port: port)
            .flatMapThrowing { channel in
                try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
            }
            .get()
        
        return try await channel.executeThenClose { inbound, outbound in
            return try await perform(TCPSocket(inbound: inbound, outbound: outbound))
        }
    }
    
    /// Send a message
    #if swift(>=6.2)
    public func send(_ message: borrowing Span<UInt8>) async throws {
        // SwiftNIO needs ownership over memory, copy over
        // In the future we want a RecvAllocator as to not allocate from scratch
        let buffer = message.withUnsafeBytes { buffer in
            ByteBuffer(bytes: buffer)
        }
        try await outbound.write(buffer)
    }
    #endif
    
    /// Convenience method for sending string messages
    public func send(_ string: String) async throws {
        try await outbound.write(ByteBuffer(string: string))
    }
    
    /// Convenience method for sending string messages
    public func send(_ bytes: [UInt8]) async throws {
        try await outbound.write(ByteBuffer(bytes: bytes))
    }
}
#endif
