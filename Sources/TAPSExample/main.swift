import TAPS

let central = try await BluetoothCentral()
try await central.withDiscovery(
    of: .any()
) { peers in
    print(peers)
}
