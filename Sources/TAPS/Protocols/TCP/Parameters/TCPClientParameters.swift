
public struct TCPClientParameters: ServiceParametersWithDefault {
    public var connectionTimeout: Duration
    public var socketParameters: TCPSocketParameters
    
    public init(
        connectionTimeout: Duration = .seconds(30),
        socketParameters: TCPSocketParameters = .defaultParameters
    ) {
        self.connectionTimeout = connectionTimeout
        self.socketParameters = socketParameters
    }
    
    public static var defaultParameters: TCPClientParameters {
        return TCPClientParameters()
    }
}