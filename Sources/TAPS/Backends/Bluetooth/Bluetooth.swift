#if canImport(DarwinGATT)
internal import Bluetooth
internal import GATT
#if canImport(DarwinGATT)
internal import DarwinGATT
#elseif canImport(BluetoothLinux)
internal import BluetoothLinux
#endif

public actor BluetoothCentral: PeerDiscoveryMechanism {
    public struct Peer: Sendable, Hashable {
        fileprivate let data: AsyncCentralScan<Central>.Element
    }
    public struct Reference: Sendable {
        internal enum Underlying: Sendable {
            case any
        }
        
        let underlying: Underlying
        
        public static func any() -> Reference {
            Reference(underlying: .any)
        }
    }
    
    fileprivate typealias Central = DarwinCentral
    private static let central = Central()
    
    public init() async throws {
        while true {
            switch await Self.central.state {
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                // Wait to become active
                try await Task.sleep(for: .seconds(1))
            case .poweredOn:
                return
            }
        }
    }
    
    public nonisolated func withDiscovery(
        of reference: Reference,
        pollingInterval: Duration? = .seconds(5),
        handleResults: @Sendable ([Peer]) async throws -> Void
    ) async throws {
        actor Output {
            var peers = [Peer]()
            
            func upsert(_ peer: Peer) {
                self.peers.removeAll {
                    $0.data.peripheral == peer.data.peripheral
                }
                self.peers.append(peer)
            }
        }
        
        let stream = try await Self.central.scan(filterDuplicates: true)
        let output = Output()
        
        try await withTaskCancellationHandler {
            for try await scanData in stream {
                let peer = Peer(data: scanData)
                await output.upsert(peer)
                try await handleResults(output.peers)
                
                if pollingInterval == nil {
                    stream.stop()
                }
            }
        } onCancel: {
            stream.stop()
        }
    }
}
#endif
