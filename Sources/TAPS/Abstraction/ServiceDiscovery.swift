// ServiceDiscovery.swift
// Service discovery extensions for dot notation API

/// Empty protocol as extension point for service discovery
public protocol ServiceDiscovery {}

/// Extension point for service discovery
extension ServiceDiscovery {
    /// TCP client service discovery
    public static func tcp(host: String, port: Int) -> TCPService {
        return TCPService(host: host, port: port)
    }
    
    // Future services will be added here:
    // public static func udp(host: String, port: Int) -> UDPService
    // public static func https(host: String, port: Int = 443) -> HTTPSService
    // public static func wss(host: String, port: Int = 443) -> WebSocketService
}