// TCPClient.swift

import Foundation
import AsyncAlgorithms
import NIOCore
import NIOPosix
import Logging

/// TCP Client as proper with real SwiftNIO implementation
@available(macOS 15.0, *)
public actor TCPClient: ClientConnectionProtocol {
    public typealias InboundMessage = TCPMessage
    public typealias OutboundMessage = TCPMessage
    
    // Actor-isolated state
    private let endpoint: EndpointIdentifier
    private let parameters: TCPParameters
    private var _state: ConnectionState = .establishing
    private var channel: Channel?
    private var eventLoopGroup: EventLoopGroup?
    private let logger: Logger
    
    // AsyncChannels for communication
    private let eventsChannel = AsyncChannel<ConnectionEvent>()
    private let messagesChannel = AsyncChannel<TCPMessage>()
    
    public var state: ConnectionState { 
        get async { _state }
    }
    public var events: AsyncChannel<ConnectionEvent> { 
        get async { eventsChannel }
    }
    public var received: AsyncChannel<TCPMessage> { 
        get async { messagesChannel }
    }
    
    // Add inbound property for API compatibility
    public var inbound: AsyncChannel<TCPMessage> { 
        get async { messagesChannel }
    }
    
    /// Initialize TCP client with endpoint and parameters
    public init(endpoint: EndpointIdentifier, parameters: TCPParameters = .defaultParameters) {
        self.endpoint = endpoint
        self.parameters = parameters
        self.logger = Logger(label: "engineer.edge.taps.tcp")
    }
    
    /// Connect to the endpoint
    public func connect() async throws {
        // Add timeout to prevent hanging
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Main connection task
            group.addTask {
                await self.establishConnection()
            }
            
            // Timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw TAPSError.timeoutExpired
            }
            
            // Wait for first task to complete
            try await group.next()
            
            // Cancel remaining tasks
            group.cancelAll()
        }
        
        // Check if connection was successful
        let currentState = await state
        if case .failed(let error) = currentState {
            throw TAPSError.connectionFailed(error)
        }
    }
    
    /// Send a message
    public func send(_ message: TCPMessage) async throws {
        guard _state == .ready else {
            throw TAPSError.connectionFailed("Connection not ready, current state: \(_state)")
        }
        
        guard let channel = channel else {
            throw TAPSError.connectionFailed("No active channel")
        }
        
        // Convert Array<UInt8> to ByteBuffer
        let content = message.content
        var buffer = channel.allocator.buffer(capacity: content.count)
        buffer.writeBytes(content)
        
        do {
            try await channel.writeAndFlush(buffer)
            
            // Log successful send
            if let stringContent = String(bytes: content, encoding: .utf8) {
                logger.debug("Sent TCP message", metadata: [
                    "content": .string(stringContent),
                    "bytes": .stringConvertible(content.count)
                ])
            } else {
                logger.debug("Sent TCP binary message", metadata: [
                    "bytes": .stringConvertible(content.count)
                ])
            }
            
        } catch {
            _state = .failed(error.localizedDescription)
            await eventsChannel.send(.failed(error.localizedDescription))
            throw TAPSError.connectionFailed(error.localizedDescription)
        }
    }
    
    /// Convenience method for sending string messages
    public func send(_ string: String) async throws {
        let message = TCPMessage(string)
        try await send(message)
    }
    
    /// Close the connection
    public func close() async throws {
        guard _state != .closed && _state != .closing else {
            return
        }
        
        _state = .closing
        
        // Close NIO channel
        if let channel = channel {
            try? await channel.close()
        }
        
        // Shutdown event loop group
        if let group = eventLoopGroup {
            try? await group.shutdownGracefully()
        }
        
        _state = .closed
        await eventsChannel.send(.closed)
        
        // Finish channels
        eventsChannel.finish()
        messagesChannel.finish()
    }
    
    // MARK: - Private Actor Methods
    
    private func establishConnection() async {
        logger.info("Establishing TCP connection", metadata: [
            "host": .string(endpoint.host),
            "port": .stringConvertible(endpoint.port)
        ])
        
        logger.info("Creating EventLoopGroup and Bootstrap")
        
        // Create event loop group
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoopGroup = group
        logger.info("EventLoopGroup created")
        
        // Bootstrap TCP connection with simpler pipeline
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: 1)
            .channelInitializer { channel in
                // Add simple raw handler that captures all data
                channel.pipeline.addHandler(RawTCPHandler { [weak self] data in
                    Task.detached { [weak self] in
                        await self?.handleIncomingMessage(data)
                    }
                })
            }
        
        logger.info("Starting connection to server")
        
        do {
            // Connect to server using EventLoopFuture with async/await bridge
            let channelFuture = bootstrap.connect(
                host: endpoint.host,
                port: endpoint.port
            )
            
            let channel = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Channel, Error>) in
                channelFuture.whenComplete { result in
                    switch result {
                    case .success(let channel):
                        continuation.resume(returning: channel)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            logger.info("Connection established, setting up channel")
            
            self.channel = channel
            logger.info("Channel assigned to actor state")
            
            // Monitor channel closure
            channel.closeFuture.whenComplete { [weak self] result in
                Task {
                    await self?.handleChannelClosure(result)
                }
            }
            logger.info("Channel closure monitoring set up")
            
            _state = .ready
            logger.info("State changed to ready")
            
            // Send ready event non-blocking
            Task {
                await eventsChannel.send(.ready)
                logger.info("Ready event sent")
            }
            
            logger.info("TCP connection established", metadata: [
                "host": .string(endpoint.host),
                "port": .stringConvertible(endpoint.port)
            ])
            
        } catch {
            _state = .failed(error.localizedDescription)
            await eventsChannel.send(.failed(error.localizedDescription))
            logger.error("Failed to establish TCP connection", metadata: [
                "error": .string(error.localizedDescription),
                "host": .string(endpoint.host),
                "port": .stringConvertible(endpoint.port)
            ])
        }
    }
    
    private func handleIncomingMessage(_ data: [UInt8]) async {
        let message = TCPMessage(content: data)
        await messagesChannel.send(message)
        
        // Log received message
        if let stringContent = String(bytes: data, encoding: .utf8) {
            logger.debug("Received TCP message", metadata: [
                "content": .string(stringContent),
                "bytes": .stringConvertible(data.count)
            ])
        } else {
            logger.debug("Received TCP binary message", metadata: [
                "bytes": .stringConvertible(data.count)
            ])
        }
    }
    
    private func handleChannelClosure(_ result: Result<Void, Error>) async {
        switch result {
        case .success:
            if _state != .closing {
                _state = .closed
                await eventsChannel.send(.closed)
            }
            
        case .failure(let error):
            _state = .failed(error.localizedDescription)
            await eventsChannel.send(.failed(error.localizedDescription))
        }
    }
  
}

// MARK: - SwiftNIO Channel Handlers

/// Simple raw TCP handler that processes all incoming data
private final class RawTCPHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = Never
    
    private let dataCallback: @Sendable ([UInt8]) -> Void
    private let logger: Logger
    
    init(dataCallback: @escaping @Sendable ([UInt8]) -> Void) {
        self.dataCallback = dataCallback
        self.logger = Logger(label: "engineer.edge.taps.nio.handler")
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let byteBuffer = unwrapInboundIn(data)
        let bytes = Array(byteBuffer.readableBytesView)
        
        logger.trace("NIO handler received data", metadata: [
            "bytes": .stringConvertible(bytes.count),
            "content": .string(String(bytes: bytes, encoding: .utf8) ?? "<binary>")
        ])
        
        dataCallback(bytes)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("NIO channel error", metadata: [
            "error": .string(error.localizedDescription)
        ])
        context.close(promise: nil)
    }
    
    func channelActive(context: ChannelHandlerContext) {
        logger.debug("NIO channel became active")
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        logger.debug("NIO channel became inactive")
    }
}
