# RFC 9621: Transport Services Architecture Summary for Swift TAPS Implementation

## Purpose and Problem

**Problem**: Existing transport APIs (Socket API) have:
- Inconsistent interfaces for different protocols
- Inability to reuse code between TCP, TLS, UDP, etc.
- Manual implementation of racing mechanisms in each application
- Difficulty optimizing for different network conditions

**Solution**: Unified Transport Services system with abstract interface for all transport protocols.

## Key Architectural Components

### 1. Transport Services System
- **Transport Services API** - abstract interface for applications
- **Transport Services Implementation** - internal implementation with protocols and objects
- Provides uniform access to different transport protocols

### 2. Core System Objects

#### Preconnection
- Object for configuring Connection before establishment
- Allows setting Transport Properties and Selection Properties
- Used to specify connection requirements

#### Connection
- Main object for working with established connection
- Abstraction over various transport protocols
- Supports sending/receiving Messages
- Can be cloned to create Connection Group

#### Message
- Unit of data transmission between Endpoints
- Can have Message Properties for transmission control
- Abstraction over different protocol data units

#### Connection Group
- Group of Connections with shared Properties and caches
- Allows optimizing resource usage
- Connections in group can use shared state

### 3. Transport Properties (RFC 9621 Section 4.1)

RFC 9621 defines three types of Transport Properties:

#### Selection Properties (Preconnection only)
- Affect path selection between Local and Remote Endpoints
- Set only before connection establishment
- **Examples**: IPv6 preference, multipath, interface selection, direction preference

#### Connection Properties (Preconnection + mutable on Connection)
- Control connection behavior
- Some can be changed after establishment
- **Examples**: connection timeout, keep-alive, no-delay, congestion control

#### Message Properties (defaults + per-message)
- Can be set as defaults on Preconnection/Connection
- Can be specified for specific Messages
- **Examples**: priority, reliability, ordering, lifetime, checksum requirements

### 4. Endpoints and Identification

#### Endpoint
- Entity participating in communication
- Can be Local Endpoint or Remote Endpoint

#### Endpoint Identifiers
- **Local Endpoint Identifier** - local endpoint identifier
- **Remote Endpoint Identifier** - remote endpoint identifier (hostname, URL)

### 5. Protocol Architecture

#### Protocol Instance
- One protocol instance with necessary state
- Can be TCP, UDP, TLS, QUIC, etc.

#### Protocol Stack
- Set of Protocol Instances used together
- For example: TLS over TCP, DTLS over UDP
- Defines complete data processing path

#### Equivalent Protocol Stacks
- Protocol Stacks that can be safely substituted
- Used during racing to select optimal variant

### 6. Racing and Connection Selection

#### Racing
- Parallel testing of multiple Protocol Stacks
- Based on Selection Properties and System Policy
- Automatic selection of optimal variant

#### Candidate Path
- One available path matching Selection Properties
- Used during racing for testing

#### Candidate Protocol Stack
- One Protocol Stack available for racing testing

### 7. State Management

#### Connection Context
- Properties storage between Connections
- Includes cached protocol and path state
- Heuristics for optimization

#### Cached State
- State and history for endpoint sets
- Used to optimize subsequent connections

#### System Policy
- Global OS or system settings
- Affect Candidate Paths and Protocol Stacks collection
- Can restrict or guide racing selection

### 8. Additional Components

#### Framer
- Data translation layer for defining Message transmission
- Determines how application-layer Messages are transmitted through Protocol Stack

#### Path
- Representation of available Properties set
- Defines how Local Endpoint can communicate with Remote Endpoint

## Architectural Principles

### 1. Asynchronicity and Events
- Event-driven interaction instead of blocking calls
- Events as primitives for communication between Endpoints

### 2. Automation
- Automatic selection of optimal protocols and paths
- Self-optimization based on network conditions and application requirements

### 3. Extensibility
- Ability to add new protocols without changing API
- Evolution of transport features without application changes

### 4. Reusability
- Connection Cloning for creating multiple connections
- Connection Groups for shared resource usage

## Key Implementation Requirements

### Mandatory (MUST/REQUIRED)
- Support for asynchronous event-driven model
- Implementation of racing mechanisms
- Ensuring memory safety when working with Messages
- Support for all three types of Transport Properties

### Recommended (SHOULD)
- Optimization based on Cached State
- Support for Connection Groups
- Integration with System Policy

### Optional (MAY)
- Protocol-specific optimizations
- Extended Framing capabilities

## TAPS Project Architecture

### Actors (Thread-Safe Concurrency)

#### Core System Actors
- **TAPS Actor**
  - Methods: `withConnection()`, `withServer()`, `withConnectionGroup()`
  - Responsibility: Main entry point for all transport operations
  
- **ConnectionManager Actor**
  - Methods: `establishConnection()`, `createListener()`
  - Responsibility: Central manager for network operations, SwiftNIO integration
  
- **Preconnection Actor**
  - Methods: `initiate()`, `listen()`, `setSelectionProperties()`
  - Responsibility: Connection configuration before establishment, properties validation
  
- **RacingEngine Actor**
  - Methods: `race()`, `establishConnection()`
  - Responsibility: Parallel testing of protocol stacks through TaskGroup
  
- **Connection Actor**
  - Methods: `send()`, `close()`, `createClient()`, `applyConnectionProperties()`
  - Responsibility: Wrapper over NIO Channel, connection lifecycle
  
- **ConnectionGroup Actor**
  - Methods: `withConnection()`, `cloneConnection()`
  - Responsibility: Managing connection groups with shared state

#### Supporting Actors
- **ConnectionPool Actor**: `getCachedConnection()`, `addConnection()` - connection caching
- **CachedStateManager Actor**: `getCachedState()`, `updateCachedState()` - optimization
- **TAPSConnectionManager Actor**: Singleton wrapper for ConnectionManager
- **ConnectionWarmer Actor**: `warmConnection()`, `getWarmedConnection()` - pre-warming
- **BufferPool Actor**: `getBuffer()`, `returnBuffer()` - memory efficiency
- **TAPSConfigurationManager Actor**: `updateConfiguration()` - global config

#### Client Implementation Actors
- **HTTPClientImpl**: HTTP client with parsing, serialization, timeout handling
- **TCPClientImpl**: Raw TCP client implementation
- **WebSocketClientImpl**: WebSocket client with frame processing

### Protocols (Interface Design)

#### Public Service Protocols
- **ClientServiceProtocol**: `makeClient()` - base for client services
- **ServerServiceProtocol**: `makeServer()` - base for server services  
- **ServiceParameters**: base service configuration
- **ServiceParametersWithDefault**: parameters with default values

#### Public Connection Protocols
- **ConnectionClient**: `send()`, `receive()`, `tryReceive()`, `inbound`, `close()`
- **ConnectionServer**: `incomingConnections`, `accept()`, `tryAccept()`, `close()`
- **HTTPClient**: HTTP methods `get()`, `post()`, `put()`, `delete()`
- **TCPClient**: `send()`, `receiveString()` - TCP operations
- **WebSocketClient**: `sendBinary()`, `sendText()`, `frames` - WebSocket ops

#### Transport Properties Protocols
- **TransportProperty**: `name`, `description` - base for all properties
- **SelectionProperty**: inherits TransportProperty - Preconnection only
- **ConnectionProperty**: `mutableAfterEstablishment` - Preconnection + Connection
- **MessageProperty**: inherits TransportProperty - defaults + per-message

#### Internal Protocols
- **BinaryParsable**: `init(parsing input: inout ParserSpan)` - binary parsing
- **BinaryWritable**: `write(to output: inout BinaryDataBuilder)` - serialization

### Structs (Value Types)

#### Public API Structs
**Service Implementations:**
- HTTPSService, TCPService, UDPService, WebSocketService, DTLSService

**HTTP Types:**
- HTTPResponse (status, headers, AsyncChannel body)
- HTTPHeaders (subscript access)
- HTTPStatus (code, reasonPhrase)

**Data Handling:**
- ReceivedData (ParserSpan wrapper, parse methods)
- CollectedData (efficient parsing access)

**Configuration:**
- TLSParameters (serverName, certificateVerification)
- DataSize (bytes, kilobytes, megabytes)

**Properties Collections:**
- SelectionProperties, ConnectionProperties, MessageProperties

#### Internal Structs
**Network Identification:**
- EndpointIdentifier (host, port, scheme, socketAddress)
- SecurityParameters (TLS config, verification, protocols)

**Protocol Description:**
- ProtocolStack (name, protocols, transportType, isSecure)
- ProtocolDescription (name, version)

**State Management:**
- CachedEndpointState (protocol stack, timing, failures)
- ConnectionStatistics (bytes, packets, timing)

**Data Processing:**
- BinaryDataBuilder (efficient binary construction)
- HTTPRequest (internal HTTP representation)

#### Specific Property Types
**Selection Properties:** IPv6Preference, MultipathPreference, DirectionPreference, InterfacePreference
**Connection Properties:** ConnectionTimeout, KeepAlive, NoDelay, CongestionControl, RetransmissionThreshold  
**Message Properties:** MessagePriority, MessageReliability, MessageOrdering, MessageLifetime, MessageChecksum

### Enums

#### Public Enums
- **HTTPBody**: empty, parserSpan, streaming, json, form
- **WebSocketFrame**: text, binary, ping, pong, close
- **HTTPVersion**: http1_1, http2, http3
- **MessagePriority.Priority**: background, low, normal, high, urgent
- **MessageReliability.Reliability**: unreliable, reliable, partiallyReliable
- **CertificateVerification**: noVerification, fullVerification
- **TAPSError**: timeout, connectionFailed, racingFailed, etc.

#### Internal Enums
- **TransportType**: tcp, udp, quic
- **HTTPMethod**: GET, POST, PUT, DELETE, etc.
- **IPv6Preference.Value**: avoid, prefer, require, default
- **CongestionControl.Algorithm**: default, cubic, bbr, reno

### Layer Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                     PUBLIC API LAYER                        │
├─────────────────────────────────────────────────────────────┤
│ TAPS Actor          │ Service Protocols │ Client Protocols  │
│ ├── withConnection  │ ├── HTTPSService  │ ├── HTTPClient    │
│ ├── withServer      │ ├── TCPService    │ ├── TCPClient     │
│ └── withGroup       │ └── WebSocket...  │ └── WebSocket...  │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   TRANSPORT PROPERTIES                      │
├─────────────────────────────────────────────────────────────┤
│ SelectionProperties │ ConnectionProperties │ MessageProperties│
│ ├── IPv6Preference  │ ├── KeepAlive       │ ├── Priority      │
│ ├── Multipath       │ ├── NoDelay         │ ├── Reliability   │
│ └── Interface       │ └── Timeout         │ └── Ordering      │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    INTERNAL CORE LAYER                      │
├─────────────────────────────────────────────────────────────┤
│ Preconnection Actor │ RacingEngine Actor │ ConnectionManager │
│ ├── Properties      │ ├── Candidate      │ ├── EventLoopGroup│
│ ├── initiate()      │ │   Stacks         │ ├── Connection    │
│ └── listen()        │ └── race()         │ │   Pool          │
│                     │                    │ └── CachedState   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 CONNECTION ABSTRACTION                      │
├─────────────────────────────────────────────────────────────┤
│ Connection Actor    │ ConnectionGroup    │ Client Impls      │
│ ├── NIO Channel     │ ├── Shared State   │ ├── HTTPClientImpl│
│ ├── Protocol Stack  │ ├── Context        │ ├── TCPClientImpl │
│ ├── send()          │ └── cloneConn()    │ └── WSClientImpl  │
│ └── AsyncChannel    │                    │                   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                  NETWORK INTEGRATION                        │
├─────────────────────────────────────────────────────────────┤
│ SwiftNIO Layer      │ Protocol Stacks    │ Data Processing   │
│ ├── ByteBuffer      │ ├── HTTP/TLS/TCP   │ ├── ParserSpan    │
│ ├── EventLoop       │ ├── WebSocket/HTTP │ ├── BinaryParsing │
│ ├── Channel         │ ├── DTLS/UDP       │ ├── AsyncChannel  │
│ └── Pipeline        │ └── Raw TCP/UDP    │ └── Backpressure  │
└─────────────────────────────────────────────────────────────┘
```

### Component Dependency Graph
```
TAPS Actor
├── TAPSConnectionManager (singleton)
│   └── ConnectionManager
│       ├── EventLoopGroup (NIO)
│       ├── ConnectionPool
│       └── CachedStateManager
├── Service Factories
│   ├── HTTPSService → HTTPClientImpl
│   ├── TCPService → TCPClientImpl
│   └── WebSocketService → WebSocketClientImpl
└── ConnectionGroup
    └── Connection[]
        ├── NIO Channel Integration
        └── AsyncChannel<ReceivedData>

Preconnection Actor
├── Properties Validation
│   ├── SelectionProperties
│   ├── ConnectionProperties
│   └── MessageProperties
├── RacingEngine
│   ├── Candidate Protocol Stacks
│   └── Parallel Racing (TaskGroup)
└── Connection Establishment
    └── Winner Protocol Stack

Data Flow: User API → Service → Preconnection → Racing → Connection → NIO
```

### RFC 9621 → Swift Implementation Mapping
```
RFC 9621 Concept           Swift Implementation
─────────────────────────  ─────────────────────────
Transport Services API  ──▶ TAPS actor + Public protocols
Preconnection          ──▶ Preconnection actor
Connection             ──▶ Connection actor + Client implementations  
Connection Group       ──▶ ConnectionGroup actor
Racing                 ──▶ RacingEngine actor + TaskGroup
Message                ──▶ ReceivedData + ParserSpan
Selection Properties   ──▶ SelectionProperty protocol + structs
Connection Properties  ──▶ ConnectionProperty protocol + structs
Message Properties     ──▶ MessageProperty protocol + structs
Events                 ──▶ AsyncChannel + async/await
System Policy          ──▶ TAPSConfigurationManager
Cached State          ──▶ CachedStateManager actor
```

### Swift Concurrency and Performance Features
```
RFC 9621 Feature           Swift Implementation
─────────────────────────  ─────────────────────────
Zero-copy Data         ──▶ ParserSpan + ByteBuffer bridge
Backpressure           ──▶ Bounded AsyncChannel
Connection Pooling     ──▶ ConnectionPool actor
Non-blocking Ops       ──▶ tryReceive() / tryAccept()
Memory Management      ──▶ BufferPool + structured concurrency
Concurrent Racing      ──▶ withThrowingTaskGroup
Resource Cleanup       ──▶ defer + withConnection pattern
Actor Isolation       ──▶ Thread-safe operations
Factory Pattern       ──▶ Service.makeClient()
Bridge Pattern         ──▶ NIO ↔ AsyncChannel integration
```

This architecture ensures full compliance with RFC 9621 while incorporating modern Swift best practices for creating a high-performance, type-safe, and extensible transport library.
