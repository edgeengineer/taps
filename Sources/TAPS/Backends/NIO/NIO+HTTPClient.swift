#if canImport(NIOPosix)
import AsyncAlgorithms
import HTTPTypes
internal import NIOCore
internal import NIOHTTP1
internal import NIOPosix
internal import NIOExtras
internal import NIOHTTPTypes
internal import NIOHTTPTypesHTTP1
import Logging

/// TCP Client as proper with real SwiftNIO implementation
@available(macOS 15.0, *)
public actor HTTP1Client: ClientConnectionProtocol {
    public typealias InboundMessage = HTTPResponse
    public typealias OutboundMessage = HTTPRequest
    public struct ConnectionError: Error {}
    
    public struct Response: Sendable {
        public let head: HTTPResponse
        public let body: AsyncThrowingChannel<NetworkInputBytes, ConnectionError>
    }
    
    // Actor-isolated state
    private nonisolated let inbound: NIOAsyncChannelInboundStream<HTTPClientResponsePart>
    private nonisolated let outbound: NIOAsyncChannelOutboundWriter<HTTPClientRequestPart>
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tcp")
    private var responseHandlers = [@Sendable (Response) async throws(ConnectionError) -> Void]()
    
    /// Initialize TCP client with endpoint and parameters
    internal init(
        inbound: NIOAsyncChannelInboundStream<HTTPClientResponsePart>,
        outbound: NIOAsyncChannelOutboundWriter<HTTPClientRequestPart>
    ) {
        self.inbound = inbound
        self.outbound = outbound
    }
    
    public func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            var iterator = inbound.makeAsyncIterator()
            
            nextResponse: while !Task.isCancelled {
                guard
                    case .head(let head) = try await iterator.next(),
                    !responseHandlers.isEmpty
                else {
                    // Protocol error
                    throw ConnectionError()
                }
                
                let handler = responseHandlers.removeFirst()
                let body = AsyncThrowingChannel<NetworkInputBytes, ConnectionError>()
                
                group.addTask {
                    do {
                        try await handler(Response(head: HTTPResponse(head), body: body))
                    } catch is ConnectionError {
                        // TODO: body.fail(error)
                        body.finish()
                    }
                }
                
                defer { body.finish() }
                while let next = try await iterator.next() {
                    switch next {
                    case .head:
                        // Protocol error
                        throw ConnectionError()
                    case .body(let buffer):
                        await body.send(NetworkInputBytes(buffer: buffer))
                    case .end:
                        return
                    }
                }
                
                throw CancellationError()
            }
        }
    }
    
    package static func withConnection<T: Sendable>(
        host: String,
        port: Int,
        parameters: HTTP1ClientParameters,
        context: TAPSContext,
        perform: @escaping @Sendable (HTTP1Client) async throws -> T
    ) async throws -> T {
        // Bootstrap TCP connection with simpler pipeline
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .applyParameters(parameters.tcp)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers()
            }
            .connect(host: host, port: port)
            .flatMapThrowing { channel in
                try NIOAsyncChannel<HTTPClientResponsePart, HTTPClientRequestPart>(wrappingChannelSynchronously: channel)
            }
            .get()
        
        return try await channel.executeThenClose { inbound, outbound in
            return try await perform(HTTP1Client(inbound: inbound, outbound: outbound))
        }
    }
    
    private nonisolated func writeRequest<BodyError: Error>(
        _ request: HTTPRequest,
        body: some AsyncSequence<NetworkOutputBytes, BodyError> & Sendable
    ) async throws {
        try await self.outbound.write(
            .head(
                HTTPRequestHead(
                    version: .http1_1,
                    method: HTTPMethod(request.method),
                    uri: request.path ?? "/",
                    headers: HTTPHeaders(request.headerFields)
                )
            )
        )
        
        for try await part in body {
            try await self.outbound.write(.body(.byteBuffer(part.buffer)))
        }
        
        try await self.outbound.write(.end(nil))
    }
    
    /// Convenience method for sending string messages
    public func withResponse<T: Sendable, E: Error>(
        to request: HTTPRequest,
        body: some AsyncSequence<NetworkOutputBytes, any Error> & Sendable = EmptySequence<NetworkOutputBytes, any Error>(),
        perform: @Sendable @escaping (Response) async throws(E) -> T
    ) async throws -> T {
        try await withThrowingTaskGroup { group in
            group.addTask {
                try await self.writeRequest(request, body: body)
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                self.responseHandlers.append { response throws(ConnectionError) -> Void in
                    do {
                        let result = try await perform(response)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                        throw ConnectionError()
                    }
                }
            }
        }
    }
}

public struct EmptySequence<Element: Sendable, Error: Swift.Error>: AsyncSequence, Sendable {
    public struct AsyncIterator: AsyncIteratorProtocol {
        public func next() async throws(Error) -> Element? {
            return nil
        }
    }
    
    public init() {}
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator()
    }
}
#endif
