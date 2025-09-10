internal import AsyncDNSResolver

public actor EdgeDiscoveryClient: PeerDiscoveryMechanism {
    public struct Reference: Sendable {
        public static func any() -> Reference {
            Reference()
        }
    }
    public struct Peer: Sendable {
        public enum Host: Sendable {
            public struct InternetHost: Sendable {
                public let hostname: String
                public let port: Int
            }
            
            case internet(InternetHost)
        }
        
        public let host: Host
        internal let txt: [TXTRecord]
    }
    
    private init() {}
    
    public static func withEdgeDiscovery<T: Sendable>(
        to nameserver: String,
        perform: (EdgeDiscoveryClient) async throws -> T
    ) async throws -> T  {
        let mdns = EdgeDiscoveryClient()
        return try await perform(mdns)
    }
    
    public nonisolated func discover(_ reference: Reference) async throws -> Peers {
        // TODO: Bluetooth in parallel
        try await MDNSClient.withMDNS { client in
            let devices = try await client.discover(.ptr(to: "_edgeos._udp.local"))
            var peers = [Peer]()
            
            for device in devices {
                let txt = try await client.discoverTXT(toHost: device.hostname)
                peers.append(
                    Peer(
                        host: .internet(.init(hostname: device.hostname, port: device.port)),
                        txt: txt
                    )
                )
            }
            
            return peers
        }
    }
}
