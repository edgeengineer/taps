// TCPTestExample.swift
// Example for testing TCP connection with real servers

import Foundation

/// Example usage of TAPS TCP client
@available(macOS 15.0, *)
public func testTCPConnection() async throws {
    let taps = TAPS()
    
    try await withThrowingTaskGroup(of: Void.self) { group in
        // Run TAPS service
        group.addTask {
            try await taps.run()
        }
        
        defer { group.cancelAll() }
        
        print("Testing TCP connection to echo server...")
        
        // Test connection to tcpbin.com echo server
        try await taps.withConnection(
            to: .tcp(host: "tcpbin.com", port: 4242)
        ) { tcpClient in
            
            print("Connected! Sending test message...")
            
            // Send test message
            try await tcpClient.send("Hello from TAPS TCP client!")
            
            // Wait a bit for response
            try await Task.sleep(for: .seconds(1))
            
            // Listen for echo response
            var messageCount = 0
            for try await message in tcpClient.inbound {
                messageCount += 1
                
                if let text = String(bytes: message.content, encoding: .utf8) {
                    print("Received echo: \(text)")
                } else {
                    print("Received binary data: \(message.content.count) bytes")
                }
                
                // Stop after first message for this test
                if messageCount >= 1 {
                    break
                }
            }
            
            print("TCP test completed successfully!")
        }
    }
}

/// Alternative test with HTTP server (raw TCP to port 80)
@available(macOS 15.0, *)
public func testHTTPRawTCP() async throws {
    let taps = TAPS()
    
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await taps.run()
        }
        
        defer { group.cancelAll() }
        
        print("Testing raw TCP to HTTP server...")
        
        try await taps.withConnection(
            to: .tcp(host: "httpbin.org", port: 80)
        ) { tcpClient in
            
            // Send raw HTTP GET request
            let httpRequest = """
            GET /get HTTP/1.1\r
            Host: httpbin.org\r
            Connection: close\r
            \r
            
            """
            
            try await tcpClient.send(httpRequest)
            
            // Read HTTP response
            for try await message in tcpClient.inbound {
                if let response = String(bytes: message.content, encoding: .utf8) {
                    print("HTTP Response:")
                    print(response)
                }
                break // HTTP with Connection: close will close after response
            }
            
            print("Raw HTTP test completed!")
        }
    }
}