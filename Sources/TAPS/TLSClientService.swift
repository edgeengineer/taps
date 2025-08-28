// TLSClientService.swift
// RFC-compliant TLS client service implementation

import Foundation

/// TLS client service implementing ClientServiceProtocol
@available(macOS 15.0, *)
public struct TLSClientService: ClientServiceProtocol, ServiceWithDefaults {
    public typealias Parameters = TLSClientParameters
    public typealias Client = TLSClient
    
    private let host: String
    private let port: Int
    
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    /// Create TLS client with given parameters and context
    public func withConnection<T: Sendable>(
        context: TAPSContext,
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        return try await TLSClient.withConnection(
            context: context,
            host: host,
            port: port,
            parameters: parameters,
            perform: perform
        )
    }
    
    // MARK: - ServiceWithDefaults
    public static var defaultParameters: TLSClientParameters {
        return TLSClientParameters.defaultParameters
    }
}

extension ClientServiceProtocol where Self == TLSClientService {
    public static func tls(host: String, port: Int) -> TLSClientService {
        TLSClientService(host: host, port: port)
    }
}

/// TLS Client service parameters with comprehensive security options
public struct TLSClientParameters: ClientServiceParametersWithDefaults {
    /// Connection timeout
    public var connectionTimeout: Duration
    
    /// TCP-level socket options
    public var keepAlive: Bool
    public var noDelay: Bool
    
    // MARK: - TLS Configuration
    
    /// TLS protocol version constraints
    public var minimumTLSVersion: TLSVersion
    public var maximumTLSVersion: TLSVersion?
    
    /// Server hostname for SNI and certificate validation
    public var serverHostname: String?
    
    /// Certificate verification mode
    public var certificateVerification: CertificateVerification
    
    /// Custom trusted certificates (PEM format)
    public var trustedCertificates: [String]
    
    // MARK: - Mutual TLS (mTLS) Support
    
    /// Client certificate for mutual authentication
    public var clientCertificate: ClientCertificate?
    
    // MARK: - Advanced TLS Options
    
    /// Cipher suites (nil means system default)
    public var cipherSuites: [String]?
    
    /// Application Layer Protocol Negotiation (ALPN) protocols
    public var alpnProtocols: [String]
    
    /// Whether to enable session resumption
    public var enableSessionResumption: Bool
    
    /// Custom certificate validation callback
    public var customCertificateValidation: (@Sendable (TLSCertificateInfo) async -> Bool)?
    
    public init(
        connectionTimeout: Duration = .seconds(30),
        keepAlive: Bool = false,
        noDelay: Bool = true,
        minimumTLSVersion: TLSVersion = .v1_2,
        maximumTLSVersion: TLSVersion? = nil,
        serverHostname: String? = nil,
        certificateVerification: CertificateVerification = .fullVerification,
        trustedCertificates: [String] = [],
        clientCertificate: ClientCertificate? = nil,
        cipherSuites: [String]? = nil,
        alpnProtocols: [String] = [],
        enableSessionResumption: Bool = true,
        customCertificateValidation: (@Sendable (TLSCertificateInfo) async -> Bool)? = nil
    ) {
        self.connectionTimeout = connectionTimeout
        self.keepAlive = keepAlive
        self.noDelay = noDelay
        self.minimumTLSVersion = minimumTLSVersion
        self.maximumTLSVersion = maximumTLSVersion
        self.serverHostname = serverHostname
        self.certificateVerification = certificateVerification
        self.trustedCertificates = trustedCertificates
        self.clientCertificate = clientCertificate
        self.cipherSuites = cipherSuites
        self.alpnProtocols = alpnProtocols
        self.enableSessionResumption = enableSessionResumption
        self.customCertificateValidation = customCertificateValidation
    }
    
    public static var defaultParameters: TLSClientParameters {
        return TLSClientParameters()
    }
}

// MARK: - TLS Configuration Types

/// TLS protocol versions
public enum TLSVersion: String, Sendable, CaseIterable {
    case v1_0 = "TLSv1.0"
    case v1_1 = "TLSv1.1"
    case v1_2 = "TLSv1.2"
    case v1_3 = "TLSv1.3"
}

/// Certificate verification modes
public enum CertificateVerification: Sendable {
    /// Full certificate chain and hostname verification (recommended)
    case fullVerification
    /// Verify certificate chain but skip hostname verification
    case certificateOnly
    /// Skip all certificate verification (dangerous - for testing only)
    case noVerification
}

/// Client certificate configuration for mTLS
public struct ClientCertificate: Sendable {
    /// Certificate chain in PEM format
    public let certificateChain: String
    /// Private key in PEM format
    public let privateKey: String
    /// Private key passphrase (if encrypted)
    public let privateKeyPassphrase: String?
    
    public init(certificateChain: String, privateKey: String, privateKeyPassphrase: String? = nil) {
        self.certificateChain = certificateChain
        self.privateKey = privateKey
        self.privateKeyPassphrase = privateKeyPassphrase
    }
}

/// TLS certificate information for custom validation
public struct TLSCertificateInfo: Sendable {
    /// Certificate chain (DER encoded)
    public let certificateChain: [Data]
    /// Peer hostname
    public let hostname: String?
    /// Whether the certificate is self-signed
    public let isSelfSigned: Bool
    
    internal init(certificateChain: [Data], hostname: String?, isSelfSigned: Bool) {
        self.certificateChain = certificateChain
        self.hostname = hostname
        self.isSelfSigned = isSelfSigned
    }
}