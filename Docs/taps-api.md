# TAPS (Transport Services).

To support this, we need to implement the following RFCs:

### RFC 9621 – Architecture: Defines the overall architecture and components of the Transport Services system.

### RFC 9622 – API: Specifies the abstract application-facing API for Transport Services.

### RFC 9623 – Implementation Guidelines: Provides guidance for implementing the API and architecture across platforms.

For connection handling, we will use SwiftNIO as the underlying transport layer.

## Target platforms:

### macOS (Apple)

### Linux

### Windows

### Embedded devices (e.g., Raspberry Pi and similar)

# TAPS Public API Design

TAPS is a library for making network connections. It is designed to be used in a Swift application.

When using TAPS, the entry point is a `TAPS` instance, which is a reference type (class/actor).
You `run()` the instance to start the service, at which point it can start making connections.

```swift
let taps = TAPS()

try await withThrowingTaskGroup(of: Void.self) { group in
    // Run TAPS as a service in parallel
    // This is needed when not using Swift Service Lifecycle
    group.addTask {
        try await taps.run()
    }

    defer { group.cancelAll() }

    // Business logic

    // Send HTTP Request
    try await taps.withConnection(
        to: .https(host: "download.example.com")
    ) { httpClient in
        // Download file
        let response = try await httpClient.get("/file.zip")

        // Stream file to different server
        try await taps.withConnection(
            to: .https(host: "upload.example.com"),
            // Optional parameters, a default is available
            parameters: HTTPSParameters(
                tlsParameters: ...
            )
        ) { httpClient in
            try await httpClient.post("/upload", body: .bytes(response.body))
        }

        // Download JSON
        let json = try await httpClient.get("/current-user")
            .collect(upTo: .megabytes(1))
            .decode(as: UserProfile.self, format: .json) // `format` is optional

        // Upload JSON
        try await httpClient.post("/current-user", body: .json(json))
    }

    // Make TCP Client Connection
    try await taps.withConnection(
        to: .tcp(host: "tcp-service.example.com", port: 1234)
    ) { tcpClient in
        try await tcpClient.send("Hello, server!")

        for try await chunk in tcpClient.inbound {
            // Echo reply back to server
            try await tcpClient.send(chunk)
        }
    }

    // Make UDP Connection
    try await taps.withConnection(
        to: .udp(host: "udp-service.example.com", port: 4321)
    ) { udpClient in
        try await udpClient.send("Hello, server!")
    }

    // Make DTLS Connection
    try await taps.withConnection(
        to: .dtls(host: "dtls-service.example.com", port: 43210),
        parameters: DTLSParameters(
            ... // Optional parameters, a default is available
        )
    ) { dtlsClient in
        try await dtlsClient.send("Hello, server!")
    }

    // Make WebSocket Connection
    try await taps.withConnection(
        to: .wss(host: "ws-service.example.com"),
        parameters: WebSocketParameters(
            maxFrameSize: .kilobytes(256)
        )
    ) { websocket in
        try await websocket.send("Hello, server!")

        for try await frame in websocket.inbound {
            // Echo reply back to server
            try await websocket.send(frame)
        }
    }
}
```

## `withConnection`

TAPS allows creating (client) connections to services.

```swift
try await taps.withConnection(
    to: .https(host: "example.com")
) { httpClient in
    // ...
}
```

Each connection points to a `service`, like `.https(host: "example.com")`.
The `RemoteService` is a protocol that can be comformed to by various service types.

```swift
protocol ClientServiceProtocol: Sendable {
    associatedtype Parameters: Sendable

    static func withConnection<T: Sendable>(
        parameters: Parameters,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T
}

/// Service parameters are used to configure the service.
protocol ServiceParametersWithDefault: ClientServiceParameters {
    static var defaultParameters: Self { get }
}
```

Like in SwiftUI, you discover supported Services by using `.` to discover the available services.
Services add themselves to `ServiceProtocol` by extending it:

```swift
extension ClientServiceProtocol {
    static func https(host: String, port: Int = 443) -> HTTPSService {
        return HTTPSService(host: host, port: port)
    }
}
```

This allows you to easily discover supported services.
For example:

```swift
struct HTTPSService: ClientServiceProtocol {
    public struct Parameters: ServiceParametersWithDefault {
        public var tlsParameters: TLSParameters

        public init(tlsParameters: TLSParameters) {
            self.tlsParameters = tlsParameters
        }

        public static var defaultParameters: Self {
            return Self(
                tlsParameters: .defaultParameters
            )
        }
    }
}
```

There are two variants of `withConnection`:

```swift
extension TAPS {
    func withConnection<Service: ClientServiceProtocol, T: Sendable>(
        to service: Service,
        parameters: Service.Parameters = .defaultParameters,
        body: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T where Service.Parameters: ServiceParametersWithDefault

    @_disfavoredOverload
    func withConnection<Service: ClientServiceProtocol, T: Sendable>(
        to service: Service,
        parameters: Service.Parameters,
        perform: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T
}
```

The first variant is for services that have a default set of parameters, whereas the second variant does not.
This allows protocols to allow a quick setup, or require certain input.

### Servers

```swift
extension TAPS {
    func withServer<Service: ServerServiceProtocol, T: Sendable>(
        on service: Service,
        parameters: Service.Parameters = .defaultParameters,
        acceptClient: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T where Service.Parameters: ServerServiceParametersWithDefault

    @_disfavoredOverload
    func withServer<Service: ServerServiceProtocol, T: Sendable>(
        on service: Service,
        parameters: Service.Parameters,
        acceptClient: @escaping @Sendable (Service.Client) async throws -> T
    ) async throws -> T
}
```

Each client is a connection handle, and functions similarly to `withConnection`.
The protocol implementation defines the operations that are available for a connection.

For example, HTTP(S) Services provide convenient HTTP verbs like `get`, `post`, `put`, `delete`, etc.

### Streams

All of the API internals need to support typed throws, so they can run in Embedded Swift mode (once Concurrency lands).
It is acceptable to only use typed throws in Embedded Swift mode, so long as the API is otherwise compatible with non-Embedded Swift.

All streams should be modeled as AsyncSequences, and must provide backpressure and must not buffer data received from the network.

This library will not depend on Foundation, or other libraries like SwiftNIO, unless it's a platform-specific implementation detail.
