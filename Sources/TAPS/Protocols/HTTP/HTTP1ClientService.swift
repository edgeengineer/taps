/// HTTP service implementing ClientServiceProtocol
public struct HTTP1ClientService: ClientServiceProtocol {
    public typealias Parameters = HTTP1ClientParameters
    public typealias Client = HTTP1Client
    
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
        return try await HTTP1Client.withConnection(
            host: host,
            port: port,
            parameters: parameters,
            context: context,
            perform: perform
        )
    }
}

extension ClientServiceProtocol where Self == HTTP1ClientService {
    public static func http1(host: String, port: Int = 80) -> HTTP1ClientService {
        HTTP1ClientService(host: host, port: port)
    }
}
