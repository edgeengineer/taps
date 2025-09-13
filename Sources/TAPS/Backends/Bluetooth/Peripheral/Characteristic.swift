public struct BluetoothCharacteristic<Value: Sendable>: Sendable {
    public let serviceId: BluetoothService.ID
    public let id: BluetoothUUID
    internal let parse: @Sendable (borrowing Span<UInt8>) throws -> Value
    
    internal init(
        id: BluetoothUUID,
        serviceId: BluetoothUUID,
        parse: @Sendable @escaping (Span<UInt8>) throws -> Value
    ) {
        self.serviceId = serviceId
        self.id = id
        self.parse = parse
    }
}

struct CharacteristicParsingError: Error {}

public enum Characteristics {
    public struct BatteryLevel: Sendable {
        public let level: UInt8
    }
}

extension BluetoothCharacteristic<Characteristics.BatteryLevel> {
    public static let batteryLevel = BluetoothCharacteristic(
        id: BluetoothUUID(uuid: .bit32(0x2a19)),
        serviceId: BluetoothUUID(uuid: .bit32(0x180f))
    ) { span in
        guard
            span.count == 1,
            0...100 ~= span[0]
        else {
            throw CharacteristicParsingError()
        }
        
        return Characteristics.BatteryLevel(level: span[0])
    }
}
