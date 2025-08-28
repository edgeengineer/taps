// TCPServerE2ETests.swift
// End-to-end tests for TCP server implementation (EDG-221)

import Testing
import Foundation
@testable import TAPS

@Suite("TCP Server Tests")
struct TCPServerTests {
    // Helper function for timeout
    func withTimeout<T: Sendable>(seconds: Int, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            
            // Main operation
            group.addTask { @Sendable in
                try await operation()
            }
            
            // Timeout task  
            group.addTask { @Sendable in
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            // Return first completed task
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {}
    struct TestFailureError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
    
    @Test("Minimal Test", .disabled())
    @available(macOS 15.0, *)
    func testTCPServerMinimal() async throws {
        print("🔄 Starting minimal TCP server test...")
        let port = 8890
        let taps = TAPS()
        
        // Start TAPS service in background
        async let _: Void = taps.run()
        
        // Wait a bit for TAPS to initialize
        try await Task.sleep(for: .milliseconds(100))
        
        // Test just server creation - no client
        print("🔄 Testing server creation...")
        
        let serverResult = try await withTimeout(seconds: 5) {
            try await taps.withServer(on: .tcp(port: port)) { tcpClient in
                print("✅ Server accepted a connection!")
                // Immediately return without doing anything with tcpClient
                return "connection-accepted"
            }
        }
        
        print("✅ Server test completed: \(serverResult)")
        #expect(serverResult == "connection-accepted", "Server should accept connection")
    }
    
    
    
    @Test("External Client Test")
    @available(macOS 15.0, *)  
    func testTCPServerWithExternalClient() async throws {
        print("🔄 Testing server with external nc client...")
        print("💡 Please run the following command in another terminal to connect:")
        print("   nc localhost 8891")
        let port = 8891
        let taps = TAPS()
        async let _: Void = taps.run()
        
        try await Task.sleep(for: .milliseconds(200))
        
        // Test server with timeout - we won't actually connect nc, just see if server can handle the setup
        print("🔄 Starting server that expects external client...")
        
        let testResult = try await withThrowingTaskGroup(of: String.self) { group in
            
            // Server task
            group.addTask { @Sendable in
                print("🔄 Server: waiting for external client...")
                do {
                    let result = try await taps.withServer(on: .tcp(port: port)) { tcpClient in
                        print("✅ Server: External client connected!")
                        return "external-client-connected"
                    }
                    return "server-result:\(result)"
                } catch {
                    print("❌ Server error: \(error)")
                    throw error
                }
            }
            
            // Timeout task
            group.addTask { @Sendable in
                try await Task.sleep(for: .seconds(30))
                return "timeout-reached"
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        
        print("✅ External client test result: \(testResult)")
        #expect(testResult.hasPrefix("server-result:"), "Server should accept external client connection")
    }
    
    @Test("Echo Test")
    @available(macOS 15.0, *)
    func testTCPServerEcho() async throws {
        print("🔄 Starting TCP server echo test...")
        let port = 8892
        let testMessage = "Hello TAPS Server!"
        let taps = TAPS()
        async let _: Void = taps.run()
        
        try await Task.sleep(for: .milliseconds(200))
        
        let testResult = try await withThrowingTaskGroup(of: String.self) { group in
            
            // Server task
            group.addTask { @Sendable in
                print("🔄 Starting echo server...")
                let result = try await taps.withServer(on: .tcp(port: port)) { tcpClient in
                    print("✅ Server: Client connected!")
                    
                    // Simple echo - read first message and echo back
                    for try await data in tcpClient.inbound {
                        let text = data.withBytes { span in
                            span.withUnsafeBufferPointer { bufferPointer in
                                String(bytes: bufferPointer, encoding: .utf8) ?? ""
                            }
                        }.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        print("✅ Server received: '\(text)'")
                        
                        // Echo back
                        try await tcpClient.send("Echo: \(text)")
                        return text
                    }
                    
                    throw TestFailureError("No data received")
                }
                return "server-result:\(result)"
            }
            
            // Client task
            group.addTask { @Sendable in
                try await Task.sleep(for: .seconds(2))
                print("🔄 Starting echo client...")
                
                let result = try await taps.withConnection(to: .tcp(host: "localhost", port: port)) { tcpClient in
                    print("✅ Client: Connected!")
                    
                    // Send test message
                    try await tcpClient.send(testMessage)
                    print("✅ Client sent: '\(testMessage)'")
                    
                    // Receive echo
                    for try await response in tcpClient.inbound {
                        
                        let text = response.withBytes { span in
                            span.withUnsafeBufferPointer { bufferPointer in
                                String(bytes: bufferPointer, encoding: .utf8) ?? ""
                            }
                        }.trimmingCharacters(in: .whitespacesAndNewlines)
                        

                        print("✅ Client received: '\(text)'")
                        return text
                    }
                    
                    throw TestFailureError("No echo received")
                }
                return "client-result:\(result)"
            }
            
            // Wait for both to complete
            var serverResult: String?
            var clientResult: String?
            
            for try await result in group {
                if result.hasPrefix("server-result:") {
                    serverResult = String(result.dropFirst("server-result:".count))
                } else if result.hasPrefix("client-result:") {
                    clientResult = String(result.dropFirst("client-result:".count))
                }
                
                if serverResult != nil && clientResult != nil {
                    break
                }
            }
            
            return "server:\(serverResult ?? "nil")|client:\(clientResult ?? "nil")"
        }
        
        print("✅ Echo test result: \(testResult)")
        
        // Verify echo worked
        #expect(testResult.contains("server:\(testMessage)"), "Server should receive original message")
        #expect(testResult.contains("client:Echo: \(testMessage)"), "Client should receive echo")
    }
    
    @Test("Connection Handling")
    @available(macOS 15.0, *)
    func testTCPServerConnectionHandling() async throws {
        let testMessage = "Connection test"
        let port = 8893
        
        let taps = TAPS()
        async let _: Void = taps.run()
        
        // Test that server properly handles connection lifecycle
        try await withThrowingTaskGroup(of: Bool.self) { group in
//            group.addTask {
//                try await taps.run()
//                return true
//            }
            group.addTask {
                try await Task.sleep(for: .milliseconds(100))
                
                let serverHandledConnection = try await taps.withServer(
                    on: .tcp(port: port)
                ) { tcpClient in
                    // Verify that we can send and receive
                    var dataReceived = false
                    
                    for try await data in tcpClient.inbound {
                        dataReceived = true
                        let text = data.withBytes { span in
                            span.withUnsafeBufferPointer { bufferPointer in
                                String(bytes: bufferPointer, encoding: .utf8) ?? ""
                            }
                        }
                        
                        // Send response
                        try await tcpClient.send("Received: \(text)")
                        break
                    }
                    
                    return dataReceived
                }
                print("✅ TCP server completed connection:\(serverHandledConnection)")
              
                return serverHandledConnection
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                
                let clientConnected = try await taps.withConnection(
                    to: .tcp(host: "localhost", port: port)
                ) { tcpClient in
                    // Send message
                    try await tcpClient.send(testMessage)
                    
                    // Verify response
                    for try await response in tcpClient.inbound {
                        let text = response.withBytes { span in
                            span.withUnsafeBufferPointer { bufferPointer in
                                String(bytes: bufferPointer, encoding: .utf8) ?? ""
                            }
                        }
                        
                        return text.contains(testMessage)
                    }
                    
                    return false
                }
                print("✅ TCP client completed connection:\(clientConnected)")
                return clientConnected
            }
            
            // Verify both server and client handled the connection properly
            var serverResult = false
            var clientResult = false
            var taskCount = 0
            
            for try await result in group {
                print("✅ Task completed with result: \(result)")
                taskCount += 1
                if taskCount == 1 {
                    serverResult = result
                } else if taskCount == 2 {
                    clientResult = result
                }
                
                if taskCount >= 2 {
                    break
                }
            }
//            group.cancelAll()
            #expect(serverResult, "Server should handle connection and receive data")
            #expect(clientResult, "Client should connect and receive response")
        }
    }
}
