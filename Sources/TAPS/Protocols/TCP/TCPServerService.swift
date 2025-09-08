public struct TCPServerService: ServerServiceProtocol {
    public typealias Parameters = TCPServerParameters
    public typealias Server = TCPServer
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    public func withServer<T: Sendable>(
        parameters: TCPServerParameters,
        context: TAPSContext,
        perform: @Sendable @escaping (TCPServer) async throws -> T
    ) async throws -> T {
        return try await TCPServer.withServer(
            host: host,
            port: port,
            parameters: parameters,
            context: context,
            perform: perform
        )
    }
}

extension ServerServiceProtocol where Self == TCPServerService {
    public static func tcp(host: String, port: Int) -> TCPServerService {
        TCPServerService(host: host, port: port)
    }
}
