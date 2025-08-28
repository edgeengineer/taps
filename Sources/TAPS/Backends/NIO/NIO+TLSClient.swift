#if canImport(NIOPosix)
import AsyncAlgorithms
import NIOCore
import NIOPosix
import NIOSSL
import Logging
import Foundation

/// TLS Client with SwiftNIO-SSL backend
@available(macOS 15.0, *)
public actor TLSClient: ClientConnectionProtocol {
    public typealias InboundMessage = NetworkBytes
    public typealias OutboundMessage = NetworkBytes
    public typealias ConnectionError = any Error
    
    // Actor-isolated state
    private nonisolated let _inbound: NIOAsyncChannelInboundStream<ByteBuffer>
    private nonisolated let outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>
    private nonisolated let logger = Logger(label: "engineer.edge.taps.tls")
    
    public nonisolated var inbound: some AsyncSequence<InboundMessage, ConnectionError> {
        _inbound.map { buffer in
            NetworkBytes(buffer: buffer)
        }
    }
    
    /// Initialize TLS client with channel streams
    internal init(
        inbound: NIOAsyncChannelInboundStream<ByteBuffer>,
        outbound: NIOAsyncChannelOutboundWriter<ByteBuffer>
    ) {
        self._inbound = inbound
        self.outbound = outbound
    }

    package static func withConnection<T: Sendable>(
        context: TAPSContext,
        host: String,
        port: Int,
        parameters: TLSClientParameters,
        perform: @escaping @Sendable (TLSClient) async throws -> T
    ) async throws -> T {
        // Create TLS configuration
        let tlsConfiguration = try createTLSConfiguration(parameters: parameters, hostname: parameters.serverHostname ?? host)
        
        // Bootstrap TLS connection
        let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .channelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: 1)
            .channelInitializer { channel in
                do {
                    let sslHandler = try NIOSSLClientHandler(context: try NIOSSLContext(configuration: tlsConfiguration), serverHostname: parameters.serverHostname ?? host)
                    return channel.pipeline.addHandler(sslHandler)
                } catch {
                    return channel.eventLoop.makeFailedFuture(error)
                }
            }
            .connect(host: host, port: port)
            .flatMapThrowing { channel in
                try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
            }
            .get()
        
        return try await channel.executeThenClose { inbound, outbound in
            return try await perform(TLSClient(inbound: inbound, outbound: outbound))
        }
    }
    
    /// Send NetworkBytes
    public func send(_ networkBytes: NetworkBytes) async throws {
        let buffer = networkBytes.withBytes { span in
            span.withUnsafeBufferPointer { bufferPointer in
                ByteBuffer(bytes: bufferPointer)
            }
        }
        try await outbound.write(buffer)
    }
    
    /// Send a message from Span
    #if swift(>=6.2)
    public func send(_ message: borrowing Span<UInt8>) async throws {
        let buffer = message.withUnsafeBufferPointer { bufferPointer in
            ByteBuffer(bytes: bufferPointer)
        }
        try await outbound.write(buffer)
    }
    #endif
    
    /// Send byte array messages
    public func send(_ bytes: [UInt8]) async throws {
        try await outbound.write(ByteBuffer(bytes: bytes))
    }
    
    /// Convenience method for sending string messages
    public func send(_ string: String) async throws {
        try await outbound.write(ByteBuffer(string: string))
    }
    
    /// Close the connection
    public func close() async throws {
        outbound.finish()
    }
    
    // MARK: - Conditional Data Type Support
    
    /// Send Foundation.Data (behind package trait)  
    public func send(_ data: Data) async throws {
        let buffer = data.withUnsafeBytes { bytes in
            ByteBuffer(bytes: bytes.bindMemory(to: UInt8.self))
        }
        try await outbound.write(buffer)
    }
    
    #if canImport(NIOCore)
    /// Send NIOCore.ByteBuffer directly (behind package trait)
    public func send(_ buffer: NIOCore.ByteBuffer) async throws {
        try await outbound.write(buffer)
    }
    #endif
}

// MARK: - TLS Configuration Helpers

private func createTLSConfiguration(parameters: TLSClientParameters, hostname: String) throws -> TLSConfiguration {
    var config = TLSConfiguration.makeClientConfiguration()
    
    // Set minimum TLS version
    config.minimumTLSVersion = try convertTLSVersion(parameters.minimumTLSVersion)
    
    // Set maximum TLS version if specified
    if let maxVersion = parameters.maximumTLSVersion {
        config.maximumTLSVersion = try convertTLSVersion(maxVersion)
    }
    
    // Configure certificate verification
    switch parameters.certificateVerification {
    case .fullVerification:
        config.certificateVerification = .fullVerification
    case .certificateOnly:
        config.certificateVerification = .noHostnameVerification
    case .noVerification:
        config.certificateVerification = .none
    }
    
    // Add custom trusted certificates
    if !parameters.trustedCertificates.isEmpty {
        var certificates: [NIOSSLCertificate] = []
        for pemData in parameters.trustedCertificates {
            let cert = try NIOSSLCertificate(bytes: Array(pemData.utf8), format: .pem)
            certificates.append(cert)
        }
        config.trustRoots = .certificates(certificates)
    }
    
    // Configure client certificate for mTLS
    if let clientCert = parameters.clientCertificate {
        let certificateChain = try NIOSSLCertificate.fromPEMBytes(Array(clientCert.certificateChain.utf8))
        let privateKey = try NIOSSLPrivateKey(bytes: Array(clientCert.privateKey.utf8), format: .pem) { callback in
            if let passphrase = clientCert.privateKeyPassphrase {
                callback(passphrase.utf8)
            } else {
                callback("".utf8)
            }
        }
        config.certificateChain = certificateChain.map { .certificate($0) }
        config.privateKey = .privateKey(privateKey)
    }
    
    // Configure cipher suites if specified
    if parameters.cipherSuites != nil {
        // Note: NIO SSL uses system default cipher suites
        // Custom cipher suite selection would require more complex configuration
    }
    
    // Configure ALPN protocols
    if !parameters.alpnProtocols.isEmpty {
        config.applicationProtocols = parameters.alpnProtocols
    }
    
    return config
}

private func convertTLSVersion(_ version: TLSVersion) throws -> TLSVersion.nioSSLVersion {
    switch version {
    case .v1_0:
        return .tlsv1
    case .v1_1:
        return .tlsv11
    case .v1_2:
        return .tlsv12
    case .v1_3:
        return .tlsv13
    }
}

// MARK: - TLS Version Extension

extension TLSVersion {
    fileprivate typealias nioSSLVersion = NIOSSL.TLSVersion
}

#endif