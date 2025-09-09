/// TCP service implementing ClientServiceProtocol
public struct TCPClientService<
    InboundMessage: Sendable,
    OutboundMessage: Sendable
>: ClientServiceProtocol {
    public typealias Parameters = TCPClientParameters
    public typealias Client = TCPSocket<InboundMessage, OutboundMessage>
    
    private let host: String
    private let port: Int
    private let protocolStack: ProtocolStack<_NetworkInputBytes, InboundMessage, OutboundMessage, _NetworkOutputBytes>
    
    public init(host: String, port: Int) where InboundMessage == NetworkInputBytes, OutboundMessage == NetworkOutputBytes {
        self.host = host
        self.port = port
        self.protocolStack = ProtocolStack()
    }
    
    /// Create TCP client with given parameters
    public func withConnection<T: Sendable>(
        parameters: Parameters,
        context: TAPSContext,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await Client.withClientConnection(
            host: host,
            port: port,
            parameters: parameters,
            context: context,
            protocolStack: protocolStack,
            perform: perform
        )
    }
}

extension ClientServiceProtocol where Self == TCPClientService<NetworkInputBytes, NetworkOutputBytes> {
    public static func tcp(host: String, port: Int) -> TCPClientService<NetworkInputBytes, NetworkOutputBytes> {
        TCPClientService(host: host, port: port)
    }
}
