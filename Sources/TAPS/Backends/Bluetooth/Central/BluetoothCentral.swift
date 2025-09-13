#if canImport(DarwinGATT)
// Bluetooth support only for Darwin currently
#if canImport(DarwinGATT)
internal import Bluetooth
internal import GATT
internal import DarwinGATT

internal typealias _BluetoothCentral = DarwinCentral
#elseif canImport(BluetoothLinux)
internal import Bluetooth
internal import BluetoothLinux
#endif

import ServiceLifecycle
import AsyncAlgorithms

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct BluetoothService: Sendable, Identifiable {
    public let id: BluetoothUUID
    public let isPrimary: Bool
}

public struct BluetoothAdvertisement: Sendable, Hashable {
    public struct ServiceData: Sendable, Hashable, Identifiable {
        public let id: BluetoothUUID
        internal let data: Data
        
        #if swift(>=6.2)
        public func withServiceData<T, E: Error>(
            _ perform: (borrowing Span<UInt8>) throws(E) -> T
        ) throws(E) -> T {
            try perform(data.span)
        }
        #endif
        
        internal init(id: Bluetooth.BluetoothUUID, data: Data) {
            self.id = BluetoothUUID(uuid: id)
            self.data = data
        }
    }
    
    private let data: _BluetoothCentral.Advertisement
    
    internal init(data: _BluetoothCentral.Advertisement) {
        self.data = data
    }
    
    public var localName: String? { data.localName }
    public var serviceData: [ServiceData]? {
        data.serviceData?.map(ServiceData.init)
    }
    public var serviceUUIDs: [BluetoothUUID]? {
        data.serviceUUIDs?.map(BluetoothUUID.init)
    }
    public var solicitedServiceUUIDs: [BluetoothUUID]? {
        data.solicitedServiceUUIDs?.map(BluetoothUUID.init)
    }
}

public actor BluetoothCentral {
    public struct Peer: Sendable, Hashable, Identifiable {
        internal let data: AsyncCentralScan<_BluetoothCentral>.Element
        public let name: String?
        
        public var discoveredAt: Date {
            data.date
        }
        public var isConnectable: Bool {
            data.isConnectable
        }
        public var id: UUID {
            data.peripheral.id
        }
        public var rssi: RSSI? {
            RSSI(data.rssi)
        }
        public var advertisement: BluetoothAdvertisement {
            BluetoothAdvertisement(data: data.advertisementData)
        }
    }
    
    public actor Peripheral: Sendable, ServiceLifecycle.Service {
        nonisolated let peripheral: _BluetoothCentral.Peripheral
        nonisolated let central: BluetoothCentral
        
        internal init(peripheral: _BluetoothCentral.Peripheral, central: BluetoothCentral) {
            self.peripheral = peripheral
            self.central = central
        }
        
        public func run() async throws {
            try await gracefulShutdown()
        }
    }
    
    private static let central = _BluetoothCentral()
    internal nonisolated let central: _BluetoothCentral
    private let inbound = AsyncChannel<_NetworkBytes>()
    
    internal init() async throws {
        self.central = Self.central
        
        while true {
            switch await central.state {
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                // Wait to become active
                try await Task.sleep(for: .seconds(1))
            case .poweredOn:
                return
            }
        }
    }
    
    public func listServices(for peer: Peer) async throws -> [BluetoothService] {
        let services = try await central.discoverServices(for: peer.data.peripheral)
        return services.map { service in
            BluetoothService(
                id: BluetoothUUID(uuid: service.uuid),
                isPrimary: service.isPrimary
            )
        }
    }
    
    internal func withConnection<T: Sendable>(
        _ peripheral: _BluetoothCentral.Peripheral,
        perform: (Peripheral) async throws -> T
    ) async throws -> T {
        try await central.connect(to: peripheral)
        
        do {
            let connected = Peripheral(
                peripheral: peripheral,
                central: self
            )
            
            let result = try await perform(connected)
            await central.disconnect(peripheral)
            return result
        } catch {
            await central.disconnect(peripheral)
            throw error
        }
    }
}
#endif
