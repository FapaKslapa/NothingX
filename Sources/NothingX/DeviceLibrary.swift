import AppKit
import IOBluetooth

extension Notification.Name {
    static let nothingDevicesChanged = Notification.Name("nothingx.devicesChanged")
}

@MainActor
@Observable
final class DeviceLibrary {
    struct Entry: Identifiable, Equatable {
        let address: String
        let name: String
        let connected: Bool
        var id: String { address }
    }

    private(set) var entries: [Entry] = []
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observer = NotificationCenter.default.addObserver(forName: .nothingDevicesChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        guard BluetoothGate.current == .allowed else { return }
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let next = paired
            .filter { DeviceKind.isNothingAudio($0.name ?? "") }
            .compactMap { device in
                device.addressString.map { Entry(address: $0, name: device.name ?? "", connected: device.isConnected()) }
            }
        if next != entries { entries = next }
    }

    func connect(_ entry: Entry) {
        guard let device = IOBluetoothDevice(addressString: entry.address) else { return }
        DispatchQueue.global(qos: .userInitiated).async { _ = device.openConnection() }
    }

    func forget(_ entry: Entry) {
        guard let device = IOBluetoothDevice(addressString: entry.address) else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = device.closeConnection()
            let remove = NSSelectorFromString("remove")
            let removed = device.responds(to: remove)
            if removed { device.perform(remove) }
            DispatchQueue.main.async {
                if !removed { BluetoothGate.openSettings() }
                self?.refresh()
            }
        }
    }
}
