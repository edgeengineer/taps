#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct BluetoothPeripheralClientService: ClientServiceProtocol {
    public typealias Parameters = BluetoothPeripheralClientParameters
    public typealias Client = BluetoothCentral.Peripheral
    
    let resolve: @Sendable (TAPSContext) async throws -> UUID
    
    internal init(
        resolve: @escaping @Sendable (TAPSContext) async throws -> UUID
    ) {
        self.resolve = resolve
    }
    
    /// Create TCP client with given parameters
    public func withConnection<T: Sendable>(
        parameters: Parameters,
        context: TAPSContext,
        perform: @escaping @Sendable (Client) async throws -> T
    ) async throws -> T {
        let deviceId = try await resolve(context)
        guard let (device, _) = await context.bluetoothCentral.central.peripherals
            .first(where: { $0.key.id == deviceId })
        else {
            throw PeerDiscoveryError()
        }
        
        return try await context.bluetoothCentral.withConnection(device) { peripheral in
            try await perform(peripheral)
        }
    }
}

extension ClientServiceProtocol where Self == BluetoothPeripheralClientService {
    public static func bluetoothPeripheral(
        _ reference: BluetoothCentral.PeripheralDiscovery.Reference
    ) -> BluetoothPeripheralClientService {
        BluetoothPeripheralClientService { context in
            let resolver = BluetoothCentral.PeripheralDiscovery(central: context.bluetoothCentral)
            let peers = try await resolver.discover(reference)
            guard let peer = peers.first else {
                throw PeerDiscoveryError.cannotResolve()
            }
            
            return peer.id
        }
    }
}
