import TAPS
import Foundation

let taps = try await TAPS()

try await withThrowingTaskGroup { group in
    group.addTask {
        try await taps.run()
    }
    
    try await taps.withConnection(
        to: .bluetoothPeripheral(.named("Joannis' iPhone"))
    ) { peripheral in
        try await peripheral.observeCharacteristic(.batteryLevel) { battery in
            print(battery.level)
        }
    }
    
    group.cancelAll()
}
