import Foundation
import ArgumentParser
import TAPS
import Logging

// MARK: - Configuration
struct TAPSConfig: Codable {
    struct Service: Codable {
        var host: String
        var port: Int
    }
    var tcp: Service?
    var http: Service?
    var tls: Service?
    var verbose: Bool?
    
    static func load(from path: String?) -> TAPSConfig {
        let url: URL
        if let path = path {
            url = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            url = home.appendingPathComponent(".tapsconfig.json")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return TAPSConfig()
        }
        return (try? JSONDecoder().decode(TAPSConfig.self, from: data)) ?? TAPSConfig()
    }
}

// MARK: - Global Options
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Option(help: "Path to config file (default: ~/.tapsconfig.json)")
    var config: String?
}

@main
struct TAPSExample: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "TAPS TCP/HTTP/TLS test client",
        subcommands: [TCP.self, HTTP.self, TLS.self, TCPServer.self, ServerOnly.self],
        defaultSubcommand: TCP.self
    )
}

protocol SubCommandProtocol: Sendable {
    var host: String? { get }
    var port: Int? { get }
    var global: GlobalOptions { get }
    var message: String { get }
}

// MARK: - TCP Subcommand
struct TCP: AsyncParsableCommand, SubCommandProtocol {
    static let configuration = CommandConfiguration(
        abstract: "Run a TCP test"
    )
    
    @Option(name: .shortAndLong, help: "Host to connect")
    var host: String?
    
    @Option(name: .shortAndLong, help: "Port to connect")
    var port: Int?
    
    @OptionGroup var global: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Message to send")
    var message : String = "Hello from TCP!\n"
    mutating func run() async throws {
        let cfg = TAPSConfig.load(from: global.config)
        
        let resolvedHost = host ?? cfg.tcp?.host ?? "tcpbin.com"
        let resolvedPort = port ?? cfg.tcp?.port ?? 4242
        let verbose = global.verbose || (cfg.verbose ?? false)
        
        if verbose {
            print("[Verbose] TCP → host=\(resolvedHost), port=\(resolvedPort), config=\(global.config ?? "~/.tapsconfig.json")")
        }
        host = resolvedHost
        port = resolvedPort
        try await runTCPClient(subCmd: self)
    }
}

// MARK: - HTTP Subcommand
struct HTTP: AsyncParsableCommand, SubCommandProtocol {
    static let configuration = CommandConfiguration(
        abstract: "Run an HTTP test"
    )
    
    @Option(name: .shortAndLong, help: "Host to connect")
    var host: String?
    
    @Option(name: .shortAndLong, help: "Port to connect")
    var port: Int?
    
    @OptionGroup var global: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Message to send")
    var message: String = "GET / HTTP/1.1\r\nHost: httpbin.org\r\nConnection: close\r\n\r\n"
    
    mutating func run() async throws {
        let cfg = TAPSConfig.load(from: global.config)
        
        let resolvedHost = host ?? cfg.http?.host ?? "httpbin.org"
        let resolvedPort = port ?? cfg.http?.port ?? 80
        let verbose = global.verbose || (cfg.verbose ?? false)
        
        if verbose {
            print("[Verbose] → host=\(resolvedHost), port=\(resolvedPort), config=\(global.config ?? "~/.tapsconfig.json")")
        }
        host = resolvedHost
        port = resolvedPort
        
        try await runTCPClient(subCmd: self)
    }
}

// MARK: - TLS Subcommand
struct TLS: AsyncParsableCommand, SubCommandProtocol {
    static let configuration = CommandConfiguration(
        abstract: "Run a TLS test"
    )
    
    @Option(name: .shortAndLong, help: "Host to connect")
    var host: String?
    
    @Option(name: .shortAndLong, help: "Port to connect")
    var port: Int?
    
    @OptionGroup var global: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Message to send")
    var message: String = "Hello from TLS TAPS!\n"
    
    mutating func run() async throws {
        let cfg = TAPSConfig.load(from: global.config)
        
        let resolvedHost = host ?? cfg.tls?.host ?? "tcpbin.com"
        let resolvedPort = port ?? cfg.tls?.port ?? 4243
        let verbose = global.verbose || (cfg.verbose ?? false)
        
        if verbose {
            print("[Verbose] TLS → host=\(resolvedHost), port=\(resolvedPort), config=\(global.config ?? "~/.tapsconfig.json")")
        }
        host = resolvedHost
        port = resolvedPort
        try await runTLSClient(subCmd: self)
    }
}

// MARK: - ServerOnly Subcommand
struct ServerOnly: AsyncParsableCommand, SubCommandProtocol {
    static let configuration = CommandConfiguration(
        commandName: "server",
        abstract: "Run TCP server only (for testing with external clients)"
    )
    
    @Option(name: .shortAndLong, help: "Host to bind (not used for server)") 
    var host: String?
    
    @Option(name: .shortAndLong, help: "Port to bind server to") 
    var port: Int?
    
    @OptionGroup var global: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Not used for server")
    var message: String = ""
    
    mutating func run() async throws {
        let resolvedPort = port ?? 8080
        let verbose = global.verbose
        
        if verbose {
            print("[Verbose] ServerOnly → port=\(resolvedPort)")
        }
        port = resolvedPort
        try await runTCPServer(subCmd: self)
    }
}

// MARK: - TCPServer Subcommand
struct TCPServer: AsyncParsableCommand, SubCommandProtocol {
    static let configuration = CommandConfiguration(
        commandName: "tcpserver",
        abstract: "Run TCP server end-to-end tests"
    )
    
    @Option(name: .shortAndLong, help: "Host to connect (not used for local test)")
    var host: String?
    
    @Option(name: .shortAndLong, help: "Port to use for test server") 
    var port: Int?
    
    @OptionGroup var global: GlobalOptions
    
    @Option(name: .shortAndLong, help: "Test message to send")
    var message: String = "Hello from TCP Server test!\n"
    
    mutating func run() async throws {
        let resolvedPort = port ?? 8080
        let verbose = global.verbose
        
        if verbose {
            print("[Verbose] TCPServer test → port=\(resolvedPort)")
        }
        port = resolvedPort
        try await runTCPServerE2ETest(subCmd: self)
    }
}

@available(macOS 15.0, *)
func runTCPClient(subCmd: any SubCommandProtocol) async throws {
    let cmdDesc = String(describing: type(of: subCmd))
    let host = subCmd.host ?? "tcpbin.com"
    let port = subCmd.port ?? 4242
    let verbose = subCmd.global.verbose
    let message = subCmd.message
    
    // Configure logging system for standalone TCP client test
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = verbose ? .trace : .info
        return handler
    }
    
    _ = try await runTCPClient(host: host, port: port, message: message, verbose: verbose, cmdDesc: cmdDesc)
}

@available(macOS 15.0, *)
func runTCPClient(host: String, port: Int, message: String, verbose: Bool = false, cmdDesc: String = "TCP") async throws -> String {
    let logger = Logger(label: "engineer.edge.taps.cli")
    logger.info("Starting TAPS \(cmdDesc) Example", metadata: [
        "host": .string(host),
        "port": .stringConvertible(port),
        "command": .string(cmdDesc)
    ])
    
    let taps = TAPS()
    
    // Start TAPS service
    async let _: Void = taps.run()
    
    let response = try await taps.withConnection(
        to: .tcp(host: host, port: port)
    ) { tcpClient -> String in
        logger.info("Connection is ready", metadata: [
            "host": "\(host)",
            "port": "\(port)"
        ])
        
        try await tcpClient.send(message)

        logger.info("Waiting for \(cmdDesc) response")
        
        // Process response
        for try await response in tcpClient.inbound {
            let text = response.withBytes { span in
                span.withUnsafeBufferPointer { bufferPointer in
                    String(bytes: bufferPointer, encoding: .utf8) ?? ""
                }
            }
            logger.info("Response received", metadata: [
                "bytes": .stringConvertible(text.count),
                "preview": .string(text.count > 200 ? String(text.prefix(200)) + "..." : text)
            ])
            
            if verbose {
                let totalBytes = response.withBytes { span in span.count }
                logger.debug("Full response details", metadata: [
                    "totalBytes": .stringConvertible(totalBytes)
                ])
            }
            
            logger.info("TCP test completed successfully")
            return text
        }
        
        throw TAPSError.serviceUnavailable("No response received")
    }
    
    logger.info("TAPS Example finished")
    return response
}

@available(macOS 15.0, *)
func runTLSClient(subCmd: any SubCommandProtocol) async throws {
    let cmdDesc = String(describing: type(of: subCmd))
    let host = subCmd.host ?? "tcpbin.com"
    let port = subCmd.port ?? 4243
    let verbose = subCmd.global.verbose
    let message = subCmd.message
    
    // Configure logging system based on verbose flag
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = verbose ? .trace : .info
        return handler
    }
    
    let logger = Logger(label: "engineer.edge.taps.cli")
    logger.info("Starting TAPS \(cmdDesc) Example", metadata: [
        "host": .string(host),
        "port": .stringConvertible(port),
        "command": .string(cmdDesc)
    ])
    
    let taps = TAPS()
    
    // Start TAPS service
    async let _: Void = taps.run()
    
    try await taps.withConnection(
        to: .tls(host: host, port: port)
    ) { tlsClient -> Void in
        logger.info("TLS Connection is ready", metadata: [
            "host": "\(host)",
            "port": "\(port)"
        ])
        
        try await tlsClient.send(message)

        logger.info("Waiting for \(cmdDesc) response")
        
        // Process response
        for try await response in tlsClient.inbound {
            let text = response.withBytes { span in
                span.withUnsafeBufferPointer { bufferPointer in
                    String(bytes: bufferPointer, encoding: .utf8) ?? ""
                }
            }
            logger.info("Response received", metadata: [
                "bytes": .stringConvertible(text.count),
                "preview": .string(text.count > 200 ? String(text.prefix(200)) + "..." : text)
            ])
            
            if verbose {
                let totalBytes = response.withBytes { span in span.count }
                logger.debug("Full TLS response details", metadata: [
                    "totalBytes": .stringConvertible(totalBytes)
                ])
            }
            break
        }
        
        logger.info("TLS test completed successfully")
    }
    
    logger.info("TAPS TLS Example finished")
}

@available(macOS 15.0, *)
func runTCPServer(subCmd: any SubCommandProtocol) async throws {
    let port = subCmd.port ?? 8080
    let verbose = subCmd.global.verbose
    
    // Configure logging system for standalone TCP server test
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = verbose ? .trace : .info
        return handler
    }
    
    try await runTCPServer(port: port, verbose: verbose)
}

@available(macOS 15.0, *)
func runTCPServer(port: Int, verbose: Bool = false) async throws {
    let logger = Logger(label: "engineer.edge.taps.server")
    
    logger.info("Starting TCP server test on port \(port)")
    
    let taps = TAPS()
    
    // Start TAPS service
    async let _: Void = taps.run()
    
    // Start TCP server
    try await taps.withServer(
        on: .tcp(port: port)
    ) { tcpClient in
        logger.info("Client connected to server")
        
        // Echo server - read and send back
        logger.info("Server starting to read from tcpClient.inbound stream...")
        for try await data in tcpClient.inbound {
            logger.info("Server received data in inbound stream!")
            let text = data.withBytes { span in
                span.withUnsafeBufferPointer { bufferPointer in
                    String(bytes: bufferPointer, encoding: .utf8) ?? ""
                }
            }
            
            logger.info("Server received: \(text)")
            
            // Echo back
            try await tcpClient.send("Echo: \(text)")
        }
        
        logger.info("Client disconnected")
    }
}

@available(macOS 15.0, *)
func runTCPServerE2ETest(subCmd: any SubCommandProtocol) async throws {
    let port = subCmd.port ?? 8080
    let message = subCmd.message
    let verbose = subCmd.global.verbose
    
    // Configure logging
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = verbose ? .trace : .info
        return handler
    }
    
    let logger = Logger(label: "engineer.edge.taps.tcpserver")
    logger.info("Starting TCP Server End-to-End Test", metadata: [
        "port": .stringConvertible(port)
    ])
    
    try await withThrowingTaskGroup(of: String.self) { group in
        
        // Start server task using existing runTCPServer function
        group.addTask { @Sendable in
            logger.info("Starting TCP server task on port \(port)")
            try await runTCPServer(port: port, verbose: verbose)
            return "server-completed"
        }
        
        // Wait for server to start
        try await Task.sleep(for: .seconds(2))
        
        // Start client task using existing runTCPClient function  
        group.addTask { @Sendable in
            logger.info("Starting TCP client task connecting to localhost:\(port)")
            
            let response = try await runTCPClient(
                host: "localhost", 
                port: port, 
                message: message, 
                verbose: verbose, 
                cmdDesc: "TCPServerTest"
            )
            
            // Verify echo response
            let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if response.contains(cleanMessage) {
                logger.info("✅ TCPServer E2E test PASSED: Echo received correctly")
            } else {
                logger.error("❌ TCPServer E2E test FAILED: Echo mismatch", metadata: [
                    "expected": .string(cleanMessage),
                    "received": .string(response)
                ])
            }
            
            return "client-completed"
        }
        
        // Wait for client to complete (server will continue running)
        var clientCompleted = false
        for try await result in group {
            if result == "client-completed" {
                clientCompleted = true
                break
            }
        }
        
        if clientCompleted {
            logger.info("TCP Server End-to-End Test finished successfully")
        }
    }
}
