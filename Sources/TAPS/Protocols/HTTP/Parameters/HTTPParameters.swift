public struct HTTP1ClientParameters: ParametersWithDefault {
    public var tcp: TCPClientParameters
    public var tls: TLSClientParameters?
    
    public init(
        tcp: TCPClientParameters,
        tls: TLSClientParameters? = nil
    ) {
        self.tcp = tcp
        self.tls = tls
    }
    
    public static var defaultParameters: HTTP1ClientParameters {
        HTTP1ClientParameters(tcp: .defaultParameters)
    }
}
