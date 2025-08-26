// TAPSTests.swift
// Tests for RFC-compliant TAPS API

import Testing
@testable import TAPS

@Test("TAPS Actor initialization")
@available(macOS 15.0, *)
func testTAPSInit() async {
    let taps = TAPS()
    let count = await taps.connectionCount
    #expect(count == 0)
}

@Test("TCP Message creation")
func testTCPMessage() {
    let message = TCPMessage("Hello, TAPS!")
    #expect(message.content == Array("Hello, TAPS!".utf8))
    #expect(message.properties.reliability == .reliable)
}

@Test("Endpoint creation")
func testEndpoint() {
    let endpoint = EndpointIdentifier(host: "example.com", port: 80)
    #expect(endpoint.host == "example.com")
    #expect(endpoint.port == 80)
}

@Test("TCP Service creation")
func testTCPService() {
    let service = TCPClientService(host: "example.com", port: 1234)
    // Test that service is created correctly
    #expect(service is TCPClientService)
}

@Test("TCP Parameters defaults")
func testTCPParameters() {
    let params = TCPParameters.defaultParameters
    #expect(params.connectionTimeout == 30.0)
    #expect(params.keepAlive == false)
    #expect(params.noDelay == true)
}

@Test("Service discovery syntax")
func testServiceDiscovery() {
    let service = TAPS.tcp(host: "example.com", port: 1234)
    #expect(service is TCPClientService)
}
