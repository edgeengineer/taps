#if canImport(NIOPosix)
import AsyncAlgorithms
import NIOCore
import NIOPosix
import Logging

/// TCP Client as proper with real SwiftNIO implementation
@available(macOS 15.0, *)
public actor TCPClient: ClientConnectionProtocol {
    public typealias InboundMessage = NetworkBytes
    public typealias OutboundMessage = NetworkBytes
    public typealias ConnectionError = any Error
    
    // Actor-isolated state
    private nonisolated let _inbound: NIOAsyncChannelInboundStream<NetworkBytes>
    private nonisolated let outbound: NIOAsyncChannelOutboundWriter<NetworkBytes>
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tcp")
    
    public nonisolated var inbound: some AsyncSequence<InboundMessage, ConnectionError> {
        _inbound
    }
    
    /// Initialize TCP client with endpoint and parameters
    internal init(
        inbound: NIOAsyncChannelInboundStream<NetworkBytes>,
        outbound: NIOAsyncChannelOutboundWriter<NetworkBytes>
    ) {
        self._inbound = inbound
        self.outbound = outbound
    }

    package static func withConnection<T: Sendable>(
        context: TAPSContext,
        host: String,
        port: Int,
        parameters: TCPClientParameters,
        perform: @escaping @Sendable (TCPClient) async throws -> T
    ) async throws -> T {
        // Bootstrap TCP connection with simpler pipeline
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .channelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: 1)
            .channelInitializer { channel in
                channel.eventLoop.makeSucceededVoidFuture()
            }
            .connect(host: host, port: port)
            .flatMapThrowing { channel in
                try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
            }
            .get()
        
        return try await channel.executeThenClose { inbound, outbound in
            return try await perform(TCPClient(inbound: inbound, outbound: outbound))
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
    
    /// Close the connection
    public func close() async throws {
        // The connection is automatically closed when the NIOAsyncChannel finishes
        // This is handled by the withConnection pattern in the static method
        outbound.finish()
    }
}
#endif
