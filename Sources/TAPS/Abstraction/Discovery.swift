public protocol PeerDiscoveryMechanism<Reference, Peer>: Sendable {
    associatedtype Reference: Sendable
    associatedtype Peer: Sendable
    associatedtype Peers: Collection<Peer> & Sendable = [Peer]
    
    func discover(_ reference: Reference) async throws -> Peers
}

extension PeerDiscoveryMechanism {
    public nonisolated func withDiscovery(
        of reference: Reference,
        pollingInterval: Duration = .seconds(5),
        handleResults: @Sendable (Peers) async throws -> Void
    ) async throws {
        while !Task.isCancelled {
            let peers = try await discover(reference)
            try await handleResults(peers)
            
            try await Task.sleep(for: pollingInterval)
        }
    }
}

public protocol InternetHost: Sendable {
    var hostname: String { get }
    var port: Int { get }
}

internal struct PeerDiscoveryError: Error {
    static func cannotResolve() -> PeerDiscoveryError {
        PeerDiscoveryError()
    }
}
