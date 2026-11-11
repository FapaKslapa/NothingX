import AppKit
import CoreBluetooth
import Foundation

enum BluetoothGate: Equatable {

    case pending

    case denied

    case allowed

    static func gate(for authorization: CBManagerAuthorization) -> BluetoothGate {
        switch authorization {
        case .notDetermined: return .pending
        case .restricted, .denied: return .denied
        case .allowedAlways: return .allowed
        @unknown default: return .denied
        }
    }

    var linkState: BluetoothLink.State? {
        switch self {
        case .pending: return .permissionPending
        case .denied: return .permissionDenied
        case .allowed: return nil
        }
    }

    static var current: BluetoothGate { gate(for: CBManager.authorization) }

    static func openSettings() {
        let urls = ["x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
                    "x-apple.systempreferences:com.apple.preference.security"]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}

final class BluetoothPermissionWatcher: NSObject, CBCentralManagerDelegate {

    var onChange: ((BluetoothGate) -> Void)?

    private let queue = DispatchQueue(label: "nx.bluetooth.permission")
    private var central: CBCentralManager?

    func start() {
        queue.async { [weak self] in
            guard let self, self.central == nil else { return }
            self.central = CBCentralManager(delegate: self, queue: self.queue,
                                            options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.central?.delegate = nil
            self?.central = nil
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let gate = BluetoothGate.current
        guard gate != .pending else { return }
        DispatchQueue.main.async { [weak self] in self?.onChange?(gate) }
    }
}
