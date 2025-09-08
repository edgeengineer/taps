// TCPTestExample.swift
// Example for testing TCP connection with real servers

import TAPS
import Testing

/// Example usage of TAPS TCP client
@Suite
struct TCPUsageTests {
    @Test(.timeLimit(.minutes(1)))
    public func testLocalTCPConnection() async throws {
        let taps = TAPS()
        let message = "Hello, server!"
        
        do {
            try await confirmation { confirm in
                try await withThrowingDiscardingTaskGroup { group in
                    // Run TAPS service
                    group.addTask {
                        try await taps.run()
                    }
                    
                    group.addTask {
                        try await taps.withServer(
                            on: .tcp(host: "127.0.0.1", port: 54_123)
                        ) { inboundClient in
                            for try await chunk in inboundClient.inbound {
                                let chunk = String(bytes: chunk)
                                #expect(chunk == message)
                                confirm()
                                return
                            }
                        }
                    }
                    
                    try await Task.sleep(for: .milliseconds(250))
                    defer { group.cancelAll() }
                    
                    try await taps.withConnection(
                        to: .tcp(host: "127.0.0.1", port: 54_123)
                    ) { client in
                        try await client.send(message)
                        
                        for try await _ in client.inbound {
                            #expect(Bool(false), "Expected no reply")
                        }
                    }
                }
            }
        } catch is CancellationError {
            // Expected
        }
    }
}
