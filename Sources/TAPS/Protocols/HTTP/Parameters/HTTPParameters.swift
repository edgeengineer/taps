public struct HTTP1ClientParameters: ServiceParametersWithDefault {
    public var tcp: TCPClientParameters
    
    public init(tcp: TCPClientParameters) {
        self.tcp = tcp
    }
    
    public static var defaultParameters: HTTP1ClientParameters {
        HTTP1ClientParameters(tcp: .defaultParameters)
    }
}
