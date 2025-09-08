/// TCP service implementing ClientServiceProtocol
public struct TCPClientService: ClientServiceProtocol {
    public typealias Parameters = TCPClientParameters
    public typealias Client = TCPSocket
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    /// Create TCP client with given parameters
    public func withConnection<T: Sendable>(
        parameters: Parameters,
        context: TAPSContext,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await TCPSocket.withClientConnection(
            host: host,
            port: port,
            parameters: parameters,
            context: context,
            perform: perform
        )
    }
}

extension ClientServiceProtocol where Self == TCPClientService {
    public static func tcp(host: String, port: Int) -> TCPClientService {
        TCPClientService(host: host, port: port)
    }
}
