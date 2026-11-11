import AppKit
import Foundation
import IOBluetooth

final class BluetoothLink: NSObject, IOBluetoothRFCOMMChannelDelegate {
    enum State { case searching, connecting, connected, permissionPending, permissionDenied }

    var onState: ((State, String?) -> Void)?
    var onFrame: ((Frame) -> Void)?

    private(set) var state: State = .searching {
        didSet { if state != oldValue { onState?(state, deviceName) } }
    }
    private(set) var deviceName: String?

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var parser = FrameParser()
    private var timer: Timer?
    private var connectNotification: IOBluetoothUserNotification?
    private var busy = false

    private var attemptStarted: Date?
    private let attemptTimeout: TimeInterval = 12

    private var gate: BluetoothGate?
    private var watcher: BluetoothPermissionWatcher?
    private var gateTimer: Timer?
    private var activeObserver: NSObjectProtocol?

    func start() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.applyGate(BluetoothGate.current) }
        applyGate(BluetoothGate.current)
    }

    func stop() {
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        activeObserver = nil
        stopWatcher()
        gateTimer?.invalidate(); gateTimer = nil
        timer?.invalidate(); timer = nil
        connectNotification?.unregister(); connectNotification = nil
        channel?.close()
    }

    private func applyGate(_ new: BluetoothGate) {
        guard new != gate else { return }
        gate = new
        switch new {
        case .allowed:
            stopWatcher()
            gateTimer?.invalidate(); gateTimer = nil
            state = .searching
            timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.tick() }
            connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
            tick()
        case .pending, .denied:

            timer?.invalidate(); timer = nil
            connectNotification?.unregister(); connectNotification = nil
            channel?.close()
            channel = nil
            device = nil
            busy = false
            parser.reset()
            if new == .pending {
                startWatcher()
            } else {
                stopWatcher()
            }
            if gateTimer == nil {

                gateTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                    self?.applyGate(BluetoothGate.current)
                }
            }
            if let closed = new.linkState { state = closed }
        }
    }

    private func startWatcher() {
        guard watcher == nil else { return }
        let w = BluetoothPermissionWatcher()
        w.onChange = { [weak self] gate in self?.applyGate(gate) }
        watcher = w
        w.start()
    }

    private func stopWatcher() {
        watcher?.stop()
        watcher = nil
    }

    private func tick() {
        guard gate == .allowed else { return }
        if busy {

            if let started = attemptStarted, Date().timeIntervalSince(started) > attemptTimeout { abortAttempt() }
            return
        }
        guard channel == nil else { return }
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        let connected = paired.filter { DeviceKind.isNothingAudio($0.name ?? "") && $0.isConnected() }
        let selected = UserDefaults.standard.string(forKey: Self.selectedKey)
        guard let dev = connected.first(where: { $0.addressString == selected }) ?? connected.first else {
            state = .searching
            return
        }
        busy = true
        attemptStarted = Date()
        device = dev
        deviceName = dev.name
        state = .connecting
        if dev.performSDPQuery(self) != kIOReturnSuccess { fail() }
    }

    static let selectedKey = "device.selected"

    func select(address: String) {
        UserDefaults.standard.set(address, forKey: Self.selectedKey)
        abortAttempt()
    }

    private func abortAttempt() {
        channel?.close()
        channel = nil
        fail()
    }

    private func fail() {
        busy = false
        attemptStarted = nil
        channel = nil
        parser.reset()
        if gate == .allowed { state = .searching }
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard gate == .allowed, status == kIOReturnSuccess, let dev = device else { return fail() }
        let uuid = IOBluetoothSDPUUID(bytes: NT.serviceUUID, length: NT.serviceUUID.count)
        var channelID: BluetoothRFCOMMChannelID = 0
        for case let record as IOBluetoothSDPServiceRecord in dev.services ?? [] {
            var id: BluetoothRFCOMMChannelID = 0
            if record.hasService(from: [uuid as Any]), record.getRFCOMMChannelID(&id) == kIOReturnSuccess {
                channelID = id
                break
            }
        }
        guard channelID != 0 else { return fail() }
        var opened: IOBluetoothRFCOMMChannel?
        if dev.openRFCOMMChannelAsync(&opened, withChannelID: channelID, delegate: self) != kIOReturnSuccess {
            return fail()
        }
        channel = opened
    }

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {

        guard rfcommChannel === channel else { rfcommChannel?.close(); return }
        busy = false
        attemptStarted = nil
        if gate != .allowed {

            rfcommChannel?.close()
            return fail()
        }
        if error == kIOReturnSuccess {
            state = .connected
        } else {
            fail()
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        DispatchQueue.main.async { [weak self] in
            NotificationCenter.default.post(name: .nothingDevicesChanged, object: nil)
            self?.tick()
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .nothingDevicesChanged, object: nil) }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        channel = nil
        NotificationCenter.default.post(name: .nothingDevicesChanged, object: nil)
        fail()
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let bytes = [UInt8](UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        for frame in parser.feed(bytes) { onFrame?(frame) }
    }

    @discardableResult
    func send(_ bytes: [UInt8]) -> Bool {
        guard let channel, state == .connected else { return false }
        var data = bytes
        let n = UInt16(data.count)
        return data.withUnsafeMutableBytes { channel.writeSync($0.baseAddress, length: n) == kIOReturnSuccess }
    }
}
