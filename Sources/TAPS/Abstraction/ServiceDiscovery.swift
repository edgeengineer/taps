// ServiceDiscovery.swift
// Service discovery extensions for dot notation API

/// Empty protocol as extension point for service discovery
public protocol ServiceDiscovery {}

/// Extension point for service discovery
extension ServiceDiscovery {
    // Future services will be added here:
    // public static func tcp(host: String, port: Int) -> TCPService
    // public static func udp(host: String, port: Int) -> UDPService
    // public static func https(host: String, port: Int = 443) -> HTTPSService
    // public static func wss(host: String, port: Int = 443) -> WebSocketService
}
