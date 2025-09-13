#if canImport(DarwinGATT)

// Bluetooth support only for Darwin currently
#if canImport(DarwinGATT)
internal import Bluetooth
internal import GATT
internal import DarwinGATT

fileprivate typealias Central = DarwinCentral
#elseif canImport(BluetoothLinux)
internal import Bluetooth
internal import BluetoothLinux
#endif

import AsyncAlgorithms
internal import NIOCore
internal import NIOPosix
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension BluetoothCentral.Peripheral {
    public struct Service: Sendable, Identifiable {
        fileprivate let underlying: _BluetoothCentral.Service
        public var id: BluetoothUUID { BluetoothUUID(uuid: underlying.uuid) }
        public var isPrimary: Bool { underlying.isPrimary}
    }
    
    public struct Characteristic: Sendable, Identifiable {
        fileprivate let underlying: _BluetoothCentral.Characteristic
        public var id: BluetoothUUID { BluetoothUUID(uuid: underlying.uuid) }
    }
    
    public var isConnected: Bool {
        get async {
            await central.central.peripherals[self.peripheral] == true
        }
    }
    
    public var name: String? {
        get async throws {
            try await central.central.name(for: peripheral)
        }
    }
    
    public var rssi: RSSI {
        get async throws {
            let rssi = try await self.central.central.rssi(for: peripheral).rawValue
            return RSSI(unchecked: rssi)
        }
    }
    
    public var services: [Service] {
        get async throws {
            let services = try await central.central.discoverServices(for: peripheral)
            return services.map { service in
                return Service(underlying: service)
            }
        }
    }
    
    public func listCharacteristics(for service: Service) async throws -> [Characteristic] {
        precondition(service.underlying.peripheral == peripheral, "Cannot find characteristics for different peripheral")
        
        let characteristics = try await central.central.discoverCharacteristics(
            for: service.underlying
        )
        return characteristics.map(Characteristic.init)
    }
    
    #if swift(>=6.2)
    public func observeCharacteristic(
        _ characteristic: Characteristic,
        perform: (borrowing Span<UInt8>) async throws -> Void
    ) async throws {
        precondition(characteristic.underlying.peripheral == peripheral, "Cannot observe characteristics for different peripheral")
        
        while !Task.isCancelled {
            let value = try await central.central.readValue(for: characteristic.underlying)
            try await perform(value.span)
        }
    }
    
    public func observeCharacteristic<Value: Sendable>(
        _ characteristic: BluetoothCharacteristic<Value>,
        perform: (Value) async throws -> Void
    ) async throws {
        let services = try await central.central.discoverServices(
            [characteristic.serviceId.uuid],
            for: peripheral
        )
        
        guard services.count == 1 else {
            return
        }
        
        let characteristics = try await central.central.discoverCharacteristics(
            [characteristic.id.uuid],
            for: services[0]
        )
        
        guard characteristics.count == 1 else {
            return
        }
        
        try await observeCharacteristic(
            Characteristic(underlying: characteristics[0])
        ) { value in
            let value = try characteristic.parse(value)
            try await perform(value)
        }
    }
    #endif
}

//public struct BluetoothServiceClient: ClientConnectionProtocol {
//    public typealias InboundMessage = String
//    public typealias OutboundMessage = Never
//    public typealias ConnectionError = any Error
//    private let peripheral: BluetoothPeripheral
//    
//    public func run() async throws {
//        // TODO: Do we need to keep `run()` active in the background?
//    }
//    
//    internal static func withClientConnection<T: Sendable>(
//        deviceId: UUID,
//        parameters: L2CAPClientParameters,
//        context: TAPSContext,
//        perform: @escaping @Sendable (L2CAPSocket<InboundMessage, OutboundMessage>) async throws -> T
//    ) async throws -> T {
//        context.bluetoothCentral
//        fatalError()
//    }
//}
#endif
