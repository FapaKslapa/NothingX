import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HeadphoneModel {
    enum Connection { case searching, connecting, connected, permissionPending, permissionDenied }

    var connection: Connection = .searching
    var deviceName = "Nothing Headphone"
    var battery: Int?
    var charging = false
    var batteryParts: [BatteryReading] = []
    var firmware: String?
    var serial: String?
    var ancRaw: UInt8?
    var lastANCLevel: UInt8 = ANCLevel.high.rawValue
    var eqPreset: UInt8?
    var eqProfile: EQProfile?
    var spatial: SpatialState?
    var bassBoostOn = false
    var bassBoostLevel: UInt8 = 6
    var gestures: [GestureBinding] = []

    var status = ""

    var macAnchored = false
    var anchorDetail = ""
    var anchorSensitivity: Double = {
        let saved = UserDefaults.standard.double(forKey: "anchor.sensitivity")
        return saved > 0 ? saved : 1.0
    }() {
        didSet { UserDefaults.standard.set(anchorSensitivity, forKey: "anchor.sensitivity") }
    }
    private let spatialEngine = SpatialAudioEngine()
    private let headPose = HeadPoseFilter()
    private var anchorTimer: Timer?
    private var anchorWanted: Bool {
        get { UserDefaults.standard.bool(forKey: "anchor.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "anchor.enabled") }
    }

    private let notifier = NotificationCoordinator()
    private let transport = BluetoothLink()
    let library = DeviceLibrary()
    let nowPlaying = NowPlayingService()
    private var opCounter: UInt8 = 0
    private var pending: [UInt8: CheckedContinuation<[UInt8]?, Never>] = [:]
    private var batteryTimer: Timer?
    private var eqCommit: Task<Void, Never>?
    private var eqCommitRunning = false
    private var eqCommitQueued = false
    private var eqEditedAt = Date.distantPast
    private(set) var linkStarted = false

    init(startLink: Bool = true, startUSBMonitor: Bool = true) {
        transport.onState = { [weak self] state, name in
            MainActor.assumeIsolated { self?.linkChanged(state, name) }
        }
        transport.onFrame = { [weak self] frame in
            MainActor.assumeIsolated { self?.handle(frame) }
        }
        if startLink { self.startLink() }
        if startUSBMonitor { self.startUSBMonitor() }

        batteryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        setUpSoftwareEQ()
    }

    func startLink() {
        guard !linkStarted else { return }
        linkStarted = true
        transport.start()
        library.start()
    }

    func connectDevice(_ entry: DeviceLibrary.Entry) {
        library.connect(entry)
        transport.select(address: entry.address)
    }

    func useDevice(_ entry: DeviceLibrary.Entry) {
        transport.select(address: entry.address)
    }

    private func linkChanged(_ state: BluetoothLink.State, _ name: String?) {
        if let name { deviceName = name }
        switch state {
        case .searching, .permissionPending, .permissionDenied:
            stopMacAnchor(remember: true)
            connection = state == .permissionPending ? .permissionPending
                : state == .permissionDenied ? .permissionDenied : .searching
            for (_, cont) in pending { cont.resume(returning: nil) }
            pending.removeAll()
            battery = nil
            batteryParts = []
            charging = false
            ancRaw = nil
            eqPreset = nil
            spatial = nil
            gestures = []
            resetDeviceSettings()
        case .connecting:
            connection = .connecting
        case .connected:
            connection = .connected
            Task {
                await refreshAll()
                if anchorWanted { await startMacAnchor() }
            }
        }
        notifier.connectionChanged(connected: connection == .connected, deviceName: deviceName)
        syncSoftwareEQ()
    }

    private func handle(_ frame: Frame) {
        if frame.cmd & 0xF000 != 0xE000, let cont = pending.removeValue(forKey: frame.opId) {
            cont.resume(returning: frame.payload)
            return
        }
        if frame.cmd == NT.Cmd.notifyANC { applyANC(frame.payload) }
        if frame.cmd == NT.Cmd.notifyHeadPose { headPose.ingest(frame.payload, now: Date.timeIntervalSinceReferenceDate) }
    }

    func request(_ cmd: UInt16, _ payload: [UInt8] = []) async -> [UInt8]? {
        guard connection == .connected else { return nil }
        opCounter = opCounter == 255 ? 1 : opCounter + 1
        let id = opCounter
        return await withCheckedContinuation { cont in
            pending[id] = cont
            guard transport.send(Codec.encode(cmd: cmd, opId: id, payload: payload)) else {
                pending[id] = nil
                cont.resume(returning: nil)
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                pending.removeValue(forKey: id)?.resume(returning: nil)
            }
        }
    }

    func refreshAll() async {
        await refreshInfo()
        await refreshBattery()
        await refreshANC()
        await refreshEQ()
        await refreshSpatial()
        await refreshGestures()
        await refreshDeviceSettings()
    }

    private var pollTick = 0

    private func poll() async {
        guard connection == .connected, pending.isEmpty else { return }
        pollTick += 1
        await refreshANC()
        if let p = await request(NT.Cmd.readSpatial), let s = SpatialState.decode(p) { spatial = s }
        if !eqBusy, let p = await request(NT.Cmd.readEQPreset), let v = p.first, v != eqPreset { eqPreset = v; await refreshEQ() }
        if pollTick % 6 == 0 || DeviceKind(name: deviceName).isEarbuds { await refreshBattery() }
        if pollTick % 6 == 3, deviceWrites == 0, !findPlaying { await refreshDeviceSettings() }
    }

    private func refreshInfo() async {
        if let p = await request(NT.Cmd.readFirmware) { firmware = String(decoding: p, as: UTF8.self) }
        if let p = await request(NT.Cmd.readDeviceInfo), p.count > 1 {

            let text = String(decoding: p.dropFirst(), as: UTF8.self)
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
                if parts.count == 3, parts[1] == "4" { serial = String(parts[2]) }
            }
        }
    }

    func refreshBattery() async {
        guard let p = await request(NT.Cmd.readBattery), p.count >= 3 else { return }
        let readings = BatteryReading.decode(p)
        batteryParts = readings
        let worn = readings.filter { $0.part != .charger }.min { $0.level < $1.level } ?? readings.first
        battery = worn?.level ?? Int(p[2] & 0x7F)
        charging = worn?.charging ?? (p[2] & 0x80 != 0)
        notifier.batteryChanged(level: battery, charging: charging, deviceName: deviceName)
    }

    func refreshANC() async {
        if let p = await request(NT.Cmd.readANC) { applyANC(p) }
    }

    func refreshEQ(keepBars: Bool = false) async {
        if let p = await request(NT.Cmd.readEQPreset), let v = p.first { eqPreset = v }
        if let p = await request(NT.Cmd.readCustomEQ, [0]), let eq = EQProfile.decode(p), !keepBars {
            eqProfile = eq
            if eqPreset == EQPreset.deviceBalanced { showGains(EQPreset.balanced.gains!) }
        }
    }

    func refreshSpatial() async {
        if let p = await request(NT.Cmd.readSpatial), let s = SpatialState.decode(p) { spatial = s }
        if let p = await request(NT.Cmd.readBassBoost), p.count >= 2 {
            bassBoostOn = p[0] != 0
            bassBoostLevel = p[1]
        }
    }

    func refreshGestures() async {
        guard let p = await request(NT.Cmd.readGestures) else { return }
        gestures = GestureBinding.decodeTable(p)
        saveOriginalGesturesIfNeeded(p)
    }

    private func applyANC(_ p: [UInt8]) {
        guard p.count >= 2 else { return }
        ancRaw = p[1]
        if p.count >= 5, (1...4).contains(p[4]) { lastANCLevel = p[4] }
        if (1...4).contains(p[1]) { lastANCLevel = p[1] }
    }

    private static func acked(_ r: [UInt8]?) -> Bool { r != nil && (r!.first ?? 0) == 0 }

    private var statusClear: Task<Void, Never>?

    private func report(_ ok: Bool, _ what: String) {
        status = ok ? "[OK]" : String(format: String(localized: "[ERROR: %@]"), what)
        statusClear?.cancel()
        statusClear = Task {
            try? await Task.sleep(for: .seconds(ok ? 2 : 6))
            if !Task.isCancelled { status = "" }
        }
    }

    func setANC(_ raw: UInt8) {
        ancRaw = raw
        if (1...4).contains(raw) { lastANCLevel = raw }
        Task {
            let r = await request(NT.Cmd.setANC, [1, raw, 0])
            report(Self.acked(r), String(localized: "ANC"))
            await refreshANC()
        }
    }

    func setANCKind(_ kind: ANCKind) {
        switch kind {
        case .anc: setANC(lastANCLevel)
        case .transparency: setANC(ANCState.transparency)
        case .off: setANC(ANCState.off)
        }
    }

    private static let customKey = "eq.custom.gains"

    private var userCustomGains: [Float] {
        get {
            if let saved = UserDefaults.standard.array(forKey: Self.customKey) as? [Double], saved.count == 8 {
                return saved.map(Float.init)
            }
            return EQPreset.balanced.gains!
        }
        set { UserDefaults.standard.set(newValue.map(Double.init), forKey: Self.customKey) }
    }

    private static func matches(_ gains: [Float], _ bands: [EQBand]) -> Bool {
        gains.count == bands.count && zip(gains, bands).allSatisfy { abs($0 - $1.gain) < 0.05 }
    }

    var selectedPreset: EQPreset? {
        guard let raw = eqPreset, let eq = eqProfile else { return nil }
        if raw == EQPreset.deviceBalanced { return .balanced }
        return EQPreset.allCases.first { $0 != .custom && Self.matches($0.gains!, eq.bands) } ?? .custom
    }

    private func showGains(_ gains: [Float]) {
        guard eqProfile != nil else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            for i in eqProfile!.bands.indices where i < gains.count { eqProfile!.bands[i].gain = gains[i] }
        }
    }

    func selectPreset(_ preset: EQPreset) {
        if isWired { return softwareSelectPreset(preset) }
        guard eqProfile != nil else { return }
        eqCommit?.cancel()
        eqCommit = nil
        eqEditedAt = Date()
        let gains = preset.gains ?? userCustomGains
        showGains(gains)
        Task {
            var ok: Bool
            if preset == .balanced {
                ok = Self.acked(await request(NT.Cmd.setEQPreset, [EQPreset.deviceBalanced, 0]))
            } else {
                ok = Self.acked(await request(NT.Cmd.setCustomEQ, eqProfile!.encode()))
                if ok { ok = Self.acked(await request(NT.Cmd.setEQPreset, [EQPreset.deviceCustom, 0])) }
            }
            await refreshEQ(keepBars: true)
            let expected = preset == .balanced ? EQPreset.deviceBalanced : EQPreset.deviceCustom
            report(ok && eqPreset == expected, String(localized: "EQ"))
        }
    }

    func setBandGain(_ index: Int, _ gain: Float) {
        if isWired { return softwareSetBandGain(index, gain) }
        guard eqProfile?.bands.indices.contains(index) == true else { return }
        eqEditedAt = Date()
        eqProfile?.bands[index].gain = gain
    }

    private var eqBusy: Bool {
        eqCommitRunning || eqCommit != nil || Date().timeIntervalSince(eqEditedAt) < 3
    }

    func commitCustomEQ() {
        if isWired { return softwareCommitCustomEQ() }
        guard let current = eqProfile else { return }
        userCustomGains = current.bands.map(\.gain)
        eqEditedAt = Date()
        if eqCommitRunning { eqCommitQueued = true; return }
        eqCommit?.cancel()
        eqCommit = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            eqCommitRunning = true
            repeat {
                eqCommitQueued = false
                guard let eq = eqProfile else { break }
                var ok = Self.acked(await request(NT.Cmd.setCustomEQ, eq.encode()))
                if ok { ok = Self.acked(await request(NT.Cmd.setEQPreset, [EQPreset.deviceCustom, 0])) }
                await refreshEQ(keepBars: true)
                report(ok && eqPreset == EQPreset.deviceCustom, String(localized: "Custom EQ"))
            } while eqCommitQueued
            eqCommitRunning = false
            eqCommit = nil
            eqEditedAt = Date()
        }
    }

    func resetCustomEQ() {
        if isWired { return softwareResetEQ() }
        guard var eq = eqProfile else { return }
        for i in eq.bands.indices { eq.bands[i].gain = 0 }
        eq.gain = 0
        eqProfile = eq
        commitCustomEQ()
    }

    var eqImportNote = ""
    private var eqNoteClear: Task<Void, Never>?

    @discardableResult
    func importEQ(from text: String) -> [String] {
        if isWired { return softwareImportEQ(text) }
        guard let current = eqProfile else {
            report(false, String(localized: "Not connected"))
            return []
        }
        guard spatial?.on != true else {
            report(false, String(localized: "EQ is disabled while spatial audio is on"))
            return []
        }
        let parsed = EQInterchange.parse(text)
        guard !parsed.filters.isEmpty else {
            report(false, String(localized: "No EQ filters found"))
            setEQImportNote(parsed.warnings)
            return parsed.warnings
        }
        let mapping = EQInterchange.map(parsed, base: current)
        withAnimation(.easeOut(duration: 0.3)) { eqProfile = mapping.profile }
        commitCustomEQ()
        setEQImportNote(mapping.warnings)
        return mapping.warnings
    }

    func exportEQ() -> String? {
        if isWired { return EQInterchange.export(softwareEQProfile) }
        return eqProfile.map(EQInterchange.export)
    }

    func reportEQFile(ok: Bool, _ what: String) { report(ok, what) }

    private func setEQImportNote(_ warnings: [String]) {
        let shown = warnings.prefix(3).joined(separator: "\n")
        let more = warnings.count > 3 ? "\n" + String(format: String(localized: "+ %d more"), warnings.count - 3) : ""
        eqImportNote = shown + more
        eqNoteClear?.cancel()
        guard !warnings.isEmpty else { return }
        eqNoteClear = Task {
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled { eqImportNote = "" }
        }
    }

    func setSpatial(on: Bool, headTracking: Bool) {
        spatial = SpatialState(on: on, headTracking: on && headTracking)
        Task {
            if on {
                if eqPreset != EQPreset.deviceBalanced {
                    _ = await request(NT.Cmd.setEQPreset, [EQPreset.deviceBalanced, 0])
                    showGains(EQPreset.balanced.gains!)
                }
                if bassBoostOn {
                    _ = await request(NT.Cmd.setBassBoost, [0, bassBoostLevel])
                }
            }
            let target = SpatialState(on: on, headTracking: on && headTracking)
            let r = await request(NT.Cmd.setSpatial, target.encode())
            await refreshSpatial()
            await refreshEQ()
            report(Self.acked(r) && spatial?.on == on, String(localized: "Spatial audio"))
        }
    }

    private var gestureBackupKey: String { "gestures.original.\(serial ?? "unknown")" }

    private func saveOriginalGesturesIfNeeded(_ payload: [UInt8]) {
        let defaults = UserDefaults.standard
        if defaults.array(forKey: gestureBackupKey) == nil {
            defaults.set(payload.map { Int($0) }, forKey: gestureBackupKey)
        }
    }


    var gesturesDifferFromOriginal: Bool {
        guard let saved = UserDefaults.standard.array(forKey: gestureBackupKey) as? [Int] else { return false }
        return GestureBinding.decodeTable(saved.map { UInt8($0) }) != gestures
    }

    func setGestureAction(_ binding: GestureBinding, action: UInt8) {
        var updated = binding
        updated.action = action
        if let i = gestures.firstIndex(where: { $0.id == binding.id }) { gestures[i] = updated }
        Task {
            let r = await request(NT.Cmd.setGestures, updated.encodeSet())
            await refreshGestures()
            let stored = gestures.first(where: { $0.id == binding.id })?.action == action
            report(Self.acked(r) && stored, String(localized: "Gestures"))
        }
    }

    func restoreOriginalGestures() {
        guard let saved = UserDefaults.standard.array(forKey: gestureBackupKey) as? [Int] else { return }
        let rows = GestureBinding.decodeTable(saved.map { UInt8($0) })
        Task {
            var ok = true
            for row in rows { ok = Self.acked(await request(NT.Cmd.setGestures, row.encodeSet())) && ok }
            await refreshGestures()
            report(ok && !gesturesDifferFromOriginal, String(localized: "Gestures"))
        }
    }

    func setMacAnchored(_ on: Bool) {
        if on { leaveSoftwareEQForMacAnchor() }
        anchorWanted = on
        if on { Task { await startMacAnchor() } } else { stopMacAnchor(remember: false) }
    }

    func recenterHead() { headPose.recenter() }

    private func startMacAnchor() async {
        guard connection == .connected, !macAnchored else { return }
        if spatial?.on == true {
            _ = await request(NT.Cmd.setSpatial, [0, 0])
            await refreshSpatial()
        }

        headPose.reset()
        _ = await request(NT.Cmd.startHeadStream)

        anchorDetail = String(localized: "Waiting for audio permission…")
        let engine = spatialEngine
        let failure: String? = await Task.detached(priority: .userInitiated) {
            do { try engine.start(outputDeviceNameContaining: "nothing"); return nil } catch { return error.localizedDescription }
        }.value
        if let failure {
            anchorWanted = false
            anchorDetail = ""
            status = String(format: String(localized: "[ERROR: %@]"), failure)
            return
        }
        guard connection == .connected, anchorWanted else { engine.stop(); anchorDetail = ""; return }
        macAnchored = true
        anchorDetail = String(localized: "Capturing system audio")

        Task {
            for attempt in 1...4 {
                try? await Task.sleep(for: .seconds(2))
                guard macAnchored, headPose.sampleCount == 0 else { return }
                _ = await request(NT.Cmd.startHeadStream)
            }
        }
        anchorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.anchorTick() }
        }
    }

    private var anchorTicks = 0
    private var lastSampleCount = 0

    private func anchorTick() {
        let a = headPose.orientation(now: Date.timeIntervalSinceReferenceDate, sensitivity: anchorSensitivity)
        anchorTicks += 1
        if anchorTicks % 30 == 0 {
            let rate = (headPose.sampleCount - lastSampleCount) * 2
            lastSampleCount = headPose.sampleCount
            anchorDetail = rate == 0
                ? String(localized: "No sensor data")
                : String(format: String(localized: "Tracking · yaw %+.0f°"), headPose.current.yaw)
        }

        spatialEngine.setListener(yaw: Float(-a.yaw), pitch: Float(a.pitch), roll: Float(-a.roll))
    }

    private func stopMacAnchor(remember: Bool) {
        anchorTimer?.invalidate(); anchorTimer = nil
        spatialEngine.stop()
        macAnchored = false
        anchorDetail = ""
        if !remember { anchorWanted = false }
    }

    private(set) var usbPresent = false {
        didSet { if oldValue != usbPresent { syncSoftwareEQ() } }
    }

    var isWired: Bool { usbPresent && connection != .connected }

    private let usbMonitor = USBHeadphoneMonitor()

    private func startUSBMonitor() {
        usbMonitor.onChange = { [weak self] present in self?.usbChanged(present) }
        usbMonitor.start()
    }

    private func usbChanged(_ present: Bool) {
        usbPresent = present

        if present, serial == nil { serial = usbMonitor.serial }

        if isWired { stopMacAnchor(remember: true) }
        WiredOutputController.shared.usbPresenceChanged(present)
    }

    var softwareEQEnabled: Bool {
        !softwareEQBlocked && softwareEQProfile.bands.contains { abs($0.gain) >= 0.05 }
    }
    private var softwareEQBlocked = false

    private var softwareEQWanted: Bool { softwareEQEnabled || softwareEQRunning || softwareEQStart != nil }
    private(set) var softwareEQRunning = false
    var softwareEQDetail = ""

    var softwareEQProfile: EQProfile = HeadphoneModel.savedSoftwareEQProfile()
    private let eqEngine = EQAudioEngine()
    private var softwareEQStart: Task<Void, Never>?
    private static let softwareEQProfileKey = "softeq.profile"

    private static func savedSoftwareEQProfile() -> EQProfile {
        if let data = UserDefaults.standard.data(forKey: softwareEQProfileKey),
           let saved = EQProfile.decode(Array(data)), saved.bands.count == SoftwareEQ.frequencies.count {
            return saved
        }
        return SoftwareEQ.profile(gains: EQPreset.balanced.gains!)
    }


    var softwareSelectedPreset: EQPreset { SoftwareEQ.preset(matching: softwareEQProfile.bands.map(\.gain)) }

    private func setUpSoftwareEQ() {
        eqEngine.onDeviceLost = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.softwareEQRunning = false
                self.softwareEQDetail = ""
                self.syncSoftwareEQ()
            }
        }
        observeWiredForSoftwareEQ()
        syncSoftwareEQ()
    }

    private func observeWiredForSoftwareEQ() {
        withObservationTracking { _ = isWired } onChange: { [weak self] in
            Task { @MainActor in
                self?.syncSoftwareEQ()
                self?.observeWiredForSoftwareEQ()
            }
        }
    }

    func syncSoftwareEQ(allowStop: Bool = true) {
        if !isWired { softwareEQBlocked = false }
        let active = softwareEQRunning || softwareEQStart != nil
        switch SoftwareEQPolicy.action(enabled: softwareEQWanted, wired: isWired,
                                       macAnchorActive: macAnchored, active: active) {
        case .start: startSoftwareEQ()
        case .stop: if allowStop { stopSoftwareEQ() }
        case .none: break
        }
    }

    private func leaveSoftwareEQForMacAnchor() {
        guard softwareEQRunning || softwareEQStart != nil else { return }
        stopSoftwareEQ()
    }

    private func startSoftwareEQ() {
        softwareEQStart = Task {
            for _ in 0..<10 {
                guard !Task.isCancelled else { return }
                guard SoftwareEQPolicy.shouldRun(enabled: softwareEQWanted, wired: isWired, macAnchorActive: macAnchored) else {
                    softwareEQStart = nil
                    softwareEQDetail = ""
                    return
                }
                if let device = AudioDevices.usbOutputDevice(forSoftwareEQ: "nothing") {

                    let engine = eqEngine, bands = softwareEQProfile.bands
                    softwareEQDetail = String(localized: "Waiting for audio permission…")
                    let failure: String? = await Task.detached(priority: .userInitiated) {
                        do { try engine.start(device: device, bands: bands); return nil } catch { return error.localizedDescription }
                    }.value
                    if let failure {

                        softwareEQBlocked = true
                        softwareEQDetail = ""
                        status = String(format: String(localized: "[ERROR: %@]"), failure)
                    } else if SoftwareEQPolicy.shouldRun(enabled: softwareEQWanted, wired: isWired, macAnchorActive: macAnchored) {
                        softwareEQRunning = true
                        softwareEQDetail = String(localized: "Equalizing system audio")
                        eqEngine.setBands(softwareEQProfile.bands)
                    } else {
                        eqEngine.stop()
                        softwareEQDetail = ""
                    }
                    softwareEQStart = nil
                    return
                }
                softwareEQDetail = String(localized: "Waiting for the headphone audio device")
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled else { return }
            softwareEQStart = nil
            softwareEQDetail = ""
            report(false, String(localized: "Headphone USB audio device not found"))
        }
    }

    private func stopSoftwareEQ() {
        softwareEQStart?.cancel()
        softwareEQStart = nil
        eqEngine.stop()
        softwareEQRunning = false
        softwareEQDetail = ""
    }

    private func softwareApplyGains(_ gains: [Float], animated: Bool) {
        var profile = softwareEQProfile
        for i in profile.bands.indices where i < gains.count { profile.bands[i].gain = SoftwareEQ.clampedGain(gains[i]) }
        if animated { withAnimation(.easeOut(duration: 0.3)) { softwareEQProfile = profile } } else { softwareEQProfile = profile }
        softwareEQBlocked = false
        eqEngine.setBands(profile.bands)
        syncSoftwareEQ(allowStop: animated)
    }

    private func saveSoftwareEQProfile() {
        UserDefaults.standard.set(Data(softwareEQProfile.encode()), forKey: Self.softwareEQProfileKey)
    }

    private func softwareSelectPreset(_ preset: EQPreset) {
        softwareApplyGains(preset.gains ?? userCustomGains, animated: true)
        saveSoftwareEQProfile()
    }

    private func softwareSetBandGain(_ index: Int, _ gain: Float) {
        guard softwareEQProfile.bands.indices.contains(index) else { return }
        var gains = softwareEQProfile.bands.map(\.gain)
        gains[index] = gain
        softwareApplyGains(gains, animated: false)
    }

    private func softwareCommitCustomEQ() {
        userCustomGains = softwareEQProfile.bands.map(\.gain)
        saveSoftwareEQProfile()
        syncSoftwareEQ()
    }

    private func softwareResetEQ() {
        softwareApplyGains([Float](repeating: 0, count: softwareEQProfile.bands.count), animated: true)
        softwareCommitCustomEQ()
    }

    private func softwareImportEQ(_ text: String) -> [String] {
        let parsed = EQInterchange.parse(text)
        guard !parsed.filters.isEmpty else {
            report(false, String(localized: "No EQ filters found"))
            setEQImportNote(parsed.warnings)
            return parsed.warnings
        }
        let mapping = EQInterchange.map(parsed, base: softwareEQProfile)
        withAnimation(.easeOut(duration: 0.3)) { softwareEQProfile = mapping.profile }
        softwareEQBlocked = false
        eqEngine.setBands(mapping.profile.bands)
        softwareCommitCustomEQ()
        setEQImportNote(mapping.warnings)
        return mapping.warnings
    }

    var lowLatency: Bool?
    var codec: AudioCodec?
    var dualConnection: Bool?
    var adaptiveANC: Bool?
    var inEarDetection: Bool?

    var findPlaying = false

    private var deviceWrites = 0

    private var codecExpectation: (codec: AudioCodec, since: Date)?
    private var findTask: Task<Void, Never>?
    private static let findPulseSeconds = 2.0

    private func resetDeviceSettings() {
        lowLatency = nil
        codec = nil
        dualConnection = nil
        adaptiveANC = nil
        inEarDetection = nil
        findTask?.cancel()
        findPlaying = false
    }

    func refreshDeviceSettings() async {
        await refreshLowLatency()
        await refreshDualConnection()
        await refreshAdaptiveANC()
        await refreshInEarDetection()
        let current = await refreshCodec()
        if let expected = codecExpectation, let current {
            codecExpectation = nil
            if Date().timeIntervalSince(expected.since) < 60 {
                report(current == expected.codec, String(localized: "Audio codec"))
            }
        }
    }

    @discardableResult
    func refreshLowLatency() async -> Bool? {
        guard let p = await request(NT.Cmd.readLowLatency), let v = DeviceSetting.decodeLowLatency(p) else { return nil }
        lowLatency = v
        return v
    }

    @discardableResult
    func refreshCodec() async -> AudioCodec? {
        guard let p = await request(NT.Cmd.readCodec) else { return nil }
        let v = AudioCodec.decode(p)
        codec = v
        return v
    }

    @discardableResult
    func refreshDualConnection() async -> Bool? {
        guard let p = await request(NT.Cmd.readDualConnection), let v = DeviceSetting.decodeFlag(p) else { return nil }
        dualConnection = v
        return v
    }

    @discardableResult
    func refreshAdaptiveANC() async -> Bool? {
        guard let p = await request(NT.Cmd.readAdaptiveANC), let v = DeviceSetting.decodeFlag(p) else { return nil }
        adaptiveANC = v
        return v
    }

    @discardableResult
    func refreshInEarDetection() async -> Bool? {
        guard let p = await request(NT.Cmd.readFeatureFlags), let table = DeviceFeatureTable.decode(p),
              let v = table.inEarDetectionOn else { return nil }
        inEarDetection = v
        return v
    }

    private func commitDeviceSetting(_ cmd: UInt16, _ payload: [UInt8], _ what: String,
                                     readBack: @escaping () async -> Bool) {
        deviceWrites += 1
        Task {
            let r = await request(cmd, payload)
            let stored = await readBack()
            deviceWrites -= 1
            report(Self.acked(r) && stored, what)
        }
    }

    func setLowLatency(_ on: Bool) {
        lowLatency = on
        commitDeviceSetting(NT.Cmd.setLowLatency, DeviceSetting.encodeLowLatency(on), String(localized: "Low latency")) {
            await self.refreshLowLatency() == on
        }
    }

    func setDualConnection(_ on: Bool) {
        dualConnection = on
        commitDeviceSetting(NT.Cmd.setDualConnection, DeviceSetting.encodeFlag(on), String(localized: "Dual connection")) {
            await self.refreshDualConnection() == on
        }
    }

    func setAdaptiveANC(_ on: Bool) {
        adaptiveANC = on
        commitDeviceSetting(NT.Cmd.setAdaptiveANC, DeviceSetting.encodeFlag(on), String(localized: "Adaptive ANC")) {
            await self.refreshAdaptiveANC() == on
        }
    }

    func setInEarDetection(_ on: Bool) {
        inEarDetection = on
        commitDeviceSetting(NT.Cmd.setFeatureFlag, DeviceFeatureTable.encodeInEarDetection(on: on),
                            String(localized: "In-ear detection")) {
            await self.refreshInEarDetection() == on
        }
    }

    func setCodec(_ newCodec: AudioCodec) {
        guard newCodec != codec else { return }
        codec = newCodec
        codecExpectation = (newCodec, Date())
        deviceWrites += 1
        Task {
            _ = await request(NT.Cmd.setCodec, newCodec.encode())
            if connection == .connected {
                var current = await refreshCodec()
                if current != newCodec && connection == .connected {
                    try? await Task.sleep(for: .seconds(4))
                    if connection == .connected { current = await refreshCodec() }
                }
                if connection == .connected, codecExpectation != nil {
                    codecExpectation = nil
                    report(current == newCodec, String(localized: "Audio codec"))
                }
            }
            deviceWrites -= 1
        }
    }

    func startFindPulse() {
        guard connection == .connected, !findPlaying else { return }
        findPlaying = true
        findTask = Task {
            let on = Self.acked(await request(NT.Cmd.findHeadphone, FindMyHeadphone.payload(on: true)))
            if on { try? await Task.sleep(for: .seconds(Self.findPulseSeconds)) }
            let off = Self.acked(await request(NT.Cmd.findHeadphone, FindMyHeadphone.payload(on: false)))
            findPlaying = false
            report(on && off, String(localized: "Find my headphone"))
        }
    }

    func stopFind() { findTask?.cancel() }
}
