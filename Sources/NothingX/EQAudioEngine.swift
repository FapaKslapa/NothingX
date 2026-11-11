import AVFoundation
import CoreAudio
import Foundation

final class EQAudioEngine {
    private(set) var isRunning = false

    var onDeviceLost: (() -> Void)?

    private let tap = SystemAudioTap(tapName: "Nothing X equalizer tap", aggregateName: "Nothing X equalizer",
                                     queueLabel: "nx.eq.tap")
    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: SoftwareEQ.frequencies.count)
    private var source: AVAudioSourceNode?
    private let ring = StereoRing()

    private var deviceUID: String?
    private var sampleRate: Double = 48_000
    private var configObserver: NSObjectProtocol?
    private var devicesListener: AudioObjectPropertyListenerBlock?

    private var appliedGains = [Float](repeating: 0, count: SoftwareEQ.frequencies.count)
    private var targetGains = [Float](repeating: 0, count: SoftwareEQ.frequencies.count)
    private var rampTimer: Timer?

    private static let rampStep: Float = 1
    private static let rampInterval: TimeInterval = 0.01

    func start(device: AudioDevices.Device, bands: [EQBand]) throws {
        guard !isRunning else { return }
        do {
            sampleRate = try tap.prepare()
            try buildGraph(outputDevice: device.id)
            configure(bands, immediately: true)
            let ring = self.ring
            try tap.startIO { l, r, frames in ring.write(l, r, frames) }
            try engine.start()
            isRunning = true
            deviceUID = device.uid
            observeDevice()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        rampTimer?.invalidate(); rampTimer = nil
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        if let devicesListener {
            var address = Self.devicesAddress
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, devicesListener)
        }
        devicesListener = nil
        if engine.isRunning { engine.stop() }
        tap.stop()
        if let source { engine.detach(source) }
        source = nil
        if eq.engine != nil { engine.detach(eq) }
        ring.reset()
        deviceUID = nil
        isRunning = false
    }

    func setBands(_ bands: [EQBand]) {
        configure(bands, immediately: !isRunning)
    }

    private func buildGraph(outputDevice: AudioObjectID) throws {
        try engine.outputNode.auAudioUnit.setDeviceID(outputDevice)
        let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let ring = self.ring
        let node = AVAudioSourceNode(format: stereo) { _, _, frameCount, bufferList in
            let list = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)
            if list.count >= 2,
               let l = list[0].mData?.assumingMemoryBound(to: Float.self),
               let r = list[1].mData?.assumingMemoryBound(to: Float.self) {
                ring.read(left: l, right: r, frames)
            } else {
                for buffer in list { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
            }
            return noErr
        }
        source = node
        engine.attach(node)
        engine.attach(eq)
        engine.connect(node, to: eq, format: stereo)
        engine.connect(eq, to: engine.mainMixerNode, format: stereo)
        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()
    }

    private func configure(_ bands: [EQBand], immediately: Bool) {
        for (i, unitBand) in eq.bands.enumerated() {
            let band = i < bands.count ? bands[i]
                : EQBand(id: i, type: 1, gain: 0, freq: SoftwareEQ.frequencies[i], q: SoftwareEQ.defaultQ)
            let p = SoftwareEQ.parameters(for: band, sampleRate: sampleRate)
            if unitBand.filterType != p.filterType { unitBand.filterType = p.filterType }
            if unitBand.frequency != p.frequency { unitBand.frequency = p.frequency }
            if unitBand.bandwidth != p.bandwidth { unitBand.bandwidth = p.bandwidth }
            if unitBand.bypass { unitBand.bypass = false }
            targetGains[i] = p.gain
        }
        if immediately {
            rampTimer?.invalidate(); rampTimer = nil
            appliedGains = targetGains
            writeGains()
        } else if rampTimer == nil, appliedGains != targetGains {
            rampTick()
            guard appliedGains != targetGains else { return }
            let timer = Timer(timeInterval: Self.rampInterval, repeats: true) { [weak self] _ in self?.rampTick() }
            RunLoop.main.add(timer, forMode: .common)
            rampTimer = timer
        }
    }

    private func rampTick() {
        appliedGains = SoftwareEQ.step(appliedGains, toward: targetGains, maxStep: Self.rampStep)
        writeGains()
        if appliedGains == targetGains { rampTimer?.invalidate(); rampTimer = nil }
    }

    private func writeGains() {
        for (i, unitBand) in eq.bands.enumerated() where i < appliedGains.count { unitBand.gain = appliedGains[i] }
        eq.globalGain = SoftwareEQ.headroom(appliedGains)
    }

    private static var devicesAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func observeDevice() {

        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.isRunning else { return }
            guard let uid = self.deviceUID, let device = AudioDevices.softwareEQDevice(uid: uid) else {
                self.deviceLost()
                return
            }
            guard !self.engine.isRunning else { return }
            try? self.engine.outputNode.auAudioUnit.setDeviceID(device.id)
            do { try self.engine.start() } catch { self.deviceLost() }
        }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self, self.isRunning, let uid = self.deviceUID else { return }
            if AudioDevices.softwareEQDevice(uid: uid) == nil { self.deviceLost() }
        }
        var address = Self.devicesAddress
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr {
            devicesListener = listener
        }
    }

    private func deviceLost() {
        guard isRunning else { return }
        stop()
        onDeviceLost?()
    }
}

final class StereoRing {
    private let capacity = 1 << 15
    private let prefill = 1024
    private let maxFill = 6144
    private let keepAfterDrop = 2048
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private var readPos = 0, writePos = 0
    private var playing = false
    private let lock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        left = .allocate(capacity: capacity)
        left.initialize(repeating: 0, count: capacity)
        right = .allocate(capacity: capacity)
        right.initialize(repeating: 0, count: capacity)
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit { left.deallocate(); right.deallocate(); lock.deallocate() }

    var fill: Int {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return writePos - readPos
    }

    func reset() {
        os_unfair_lock_lock(lock)
        readPos = 0; writePos = 0; playing = false
        os_unfair_lock_unlock(lock)
    }

    func write(_ l: UnsafePointer<Float>, _ r: UnsafePointer<Float>, _ count: Int) {
        os_unfair_lock_lock(lock)
        for i in 0..<count {
            let index = (writePos + i) & (capacity - 1)
            left[index] = l[i]
            right[index] = r[i]
        }
        writePos += count
        if writePos - readPos > maxFill { readPos = writePos - keepAfterDrop }
        os_unfair_lock_unlock(lock)
    }

    func read(left dstL: UnsafeMutablePointer<Float>, right dstR: UnsafeMutablePointer<Float>, _ count: Int) {
        os_unfair_lock_lock(lock)
        let available = writePos - readPos
        if !playing { playing = available >= prefill }
        var produced = 0
        if playing {
            produced = min(available, count)
            for i in 0..<produced {
                let index = (readPos + i) & (capacity - 1)
                dstL[i] = left[index]
                dstR[i] = right[index]
            }
            readPos += produced
            if produced < count { playing = false }
        }
        os_unfair_lock_unlock(lock)
        if produced < count {
            for i in produced..<count { dstL[i] = 0; dstR[i] = 0 }
        }
    }
}

extension AudioDevices {

    static func usbOutputDevice(forSoftwareEQ fragment: String) -> Device? {
        let usb = softwareEQOutputDevices().first {
            $0.name.localizedCaseInsensitiveContains(fragment) && softwareEQTransport($0.id) == kAudioDeviceTransportTypeUSB
        }
        if let usb { return usb }
        guard let fallback = outputDevice(nameContaining: fragment) else { return nil }
        let transport = softwareEQTransport(fallback.id)
        let bluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        return bluetooth ? nil : fallback
    }

    static func softwareEQDevice(uid: String) -> Device? {
        softwareEQOutputDevices().first { $0.uid == uid }
    }

    private static func softwareEQAddress(_ selector: AudioObjectPropertySelector,
                                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func softwareEQString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = softwareEQAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func softwareEQTransport(_ device: AudioObjectID) -> UInt32? {
        var addr = softwareEQAddress(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func softwareEQOutputDevices() -> [Device] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var addr = softwareEQAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = softwareEQAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0,
                  let name = softwareEQString(id, kAudioObjectPropertyName),
                  let uid = softwareEQString(id, kAudioDevicePropertyDeviceUID) else { return nil }
            return Device(id: id, uid: uid, name: name)
        }
    }
}
