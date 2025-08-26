import Foundation
import ArgumentParser
import TAPS
import Logging

// MARK: - Конфигурация
struct TAPSConfig: Codable {
    struct Service: Codable {
        var host: String
        var port: Int
    }
    var tcp: Service?
    var http: Service?
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

// MARK: - Глобальные опции
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Option(help: "Path to config file (default: ~/.tapsconfig.json)")
    var config: String?
}

@main
struct TAPSExample: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "TAPS TCP/HTTP test client",
        subcommands: [TCP.self, HTTP.self],
        defaultSubcommand: TCP.self
    )
}

protocol SubCommandProtocol: Sendable {
    var host: String? { get }
    var port: Int? { get }
    var global: GlobalOptions { get }
    var message: String { get }
}

// MARK: - Подкоманда TCP
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

// MARK: - Подкоманда HTTP
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

@available(macOS 15.0, *)
func runTCPClient(subCmd: any SubCommandProtocol) async throws {
    let cmdDesc = String(describing: type(of: subCmd))
    let host = subCmd.host ?? "tcpbin.com"
    let port = subCmd.port ?? 4242
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
        to: .tcp(host: host, port: port)
    ) { tcpClient -> Void in
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
            break
        }
        
        logger.info("TCP test completed successfully")
    }
    
    logger.info("TAPS Example finished")
}

@available(macOS 15.0, *)
func runTCPServer(subCmd: any SubCommandProtocol) async throws {
}
