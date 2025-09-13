#if canImport(DarwinGATT)
#if canImport(DarwinGATT)
internal import Bluetooth
internal import GATT
internal import DarwinGATT
#elseif canImport(BluetoothLinux)
internal import Bluetooth
internal import BluetoothLinux
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor BluetoothPeripheral {
    fileprivate typealias Peripheral = DarwinPeripheral
    private static let peripheral = Peripheral()
    
    internal init() async throws {
        while true {
            switch Self.peripheral.state {
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                // Wait to become active
                try await Task.sleep(for: .seconds(1))
            case .poweredOn:
                return
            }
        }
    }

    internal func run(
        localName: String?
    ) async throws {
        try await withTaskCancellationHandler {
            try await Self.peripheral.start(options: Peripheral.AdvertisingOptions(localName: localName))
            while true {
                try await Task.sleep(for: .seconds(100_000))
            }
        } onCancel: {
            Self.peripheral.stop()
        }
    }
    
//    internal func run<each Service: BluetoothService>(
//        localName: String?,
//        services: repeat each Service
//    ) async throws {
//        try await withTaskCancellationHandler {
//            var uuids = [Bluetooth.BluetoothUUID]()
//            for service in repeat each services {
//                uuids.append(service.uuid.uuid)
//            }
//            try await Self.peripheral.start(
//                options: Peripheral.AdvertisingOptions(
//                    localName: localName,
//                    serviceUUIDs: uuids
//                )
//            )
//            while true {
//                try await Task.sleep(for: .seconds(100_000))
//            }
//        } onCancel: {
//            Self.peripheral.stop()
//        }
//    }
}
#endif
