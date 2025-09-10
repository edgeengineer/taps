internal import AsyncDNSResolver

public actor MDNSClient: PeerDiscoveryMechanism {
    public struct Reference: Sendable {
        internal enum Underlying: Sendable {
            case ptr(String)
            case srv(String)
        }
        
        let underlying: Underlying
        
        public static func ptr(to host: String) -> Reference {
            Reference(underlying: .ptr(host))
        }
        
        public static func srv(to host: String) -> Reference {
            Reference(underlying: .ptr(host))
        }
    }
    public struct Peer: Sendable {
        public let hostname: String
        public let port: Int
    }
    
    private init() {}
    
    public static func withMDNS<T: Sendable>(
        perform: (MDNSClient) async throws -> T
    ) async throws -> T  {
        let mdns = MDNSClient()
        return try await perform(mdns)
    }
    
    internal func discoverTXT(toHost name: String) async throws -> [TXTRecord] {
        let resolver = try AsyncDNSResolver()
        return try await resolver.queryTXT(name: name)
    }
    
    public nonisolated func discover(_ reference: Reference) async throws -> Peers {
        var peers = [Peer]()
        let resolver = try AsyncDNSResolver()
        
        switch reference.underlying {
        case .ptr(let name):
            let ptr = try await resolver.queryPTR(name: name)
            for name in ptr.names {
                guard let srv = try await resolver.querySRV(name: name).first else {
                    continue
                }

                let peer = Peer(
                    hostname: srv.host,
                    port: Int(srv.port)
                )

                // Prevent duplicates
                if !peers.contains(where: { $0.hostname == peer.hostname }) {
                    peers.append(peer)
                }
            }

            return peers
        case .srv(let name):
            guard let srv = try await resolver.querySRV(name: name).first else {
                return []
            }

            let peer = Peer(
                hostname: srv.host,
                port: Int(srv.port)
            )

            return [peer]
        }
    }
}
