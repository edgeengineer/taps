public protocol PeerDiscoveryMechanism<Reference, Peer>: Sendable {
    associatedtype Reference: Sendable
    associatedtype Peer: Sendable

    func withDiscovery(
        of reference: Reference,
        pollingInterval: Duration?,
        handleResults: @Sendable ([Peer]) async throws -> Void
    ) async throws
}

fileprivate actor Output<Peer: Sendable> {
    var peers = [Peer]()
    func update(to peers: [Peer]) {
        self.peers = peers
    }
}

extension PeerDiscoveryMechanism {
    public func discover(_ reference: Reference) async throws -> [Peer] {
        let output = Output<Peer>()
        try await withDiscovery(
            of: reference,
            pollingInterval: nil
        ) { results in
            await output.update(to: results)
        }
        return await output.peers
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
