import CoreAudio
import Foundation
import Observation

extension AudioDevices {
    private static func addr(_ selector: AudioObjectPropertySelector,
                             scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func allDeviceIDs() -> [AudioObjectID] {
        var a = addr(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func cfString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var a = addr(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &a, 0, nil, &size, $0) }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func transportType(_ object: AudioObjectID) -> UInt32? {
        var a = addr(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func hasOutputStreams(_ object: AudioObjectID) -> Bool {
        var a = addr(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(object, &a, 0, nil, &size) == noErr && size > 0
    }

    private static func describe(_ id: AudioObjectID) -> Device? {
        guard let uid = cfString(id, kAudioDevicePropertyDeviceUID) else { return nil }
        return Device(id: id, uid: uid, name: cfString(id, kAudioObjectPropertyName) ?? "")
    }

    static func usbOutputDevice(nameContaining fragment: String = "Nothing Headphone") -> Device? {
        for id in allDeviceIDs() {
            guard transportType(id) == kAudioDeviceTransportTypeUSB,
                  hasOutputStreams(id),
                  let device = describe(id),
                  device.name.localizedCaseInsensitiveContains(fragment) else { continue }
            return device
        }
        return nil
    }

    static func defaultOutputDevice() -> Device? {
        var a = addr(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &id) == noErr, id != kAudioObjectUnknown else { return nil }
        return describe(id)
    }

    static func outputDevice(uid: String) -> Device? {
        for id in allDeviceIDs() where hasOutputStreams(id) {
            if let device = describe(id), device.uid == uid { return device }
        }
        return nil
    }

    @discardableResult
    static func setDefaultOutputDevice(_ device: Device) -> Bool {
        var a = addr(kAudioHardwarePropertyDefaultOutputDevice)
        var id = device.id
        return AudioObjectSetPropertyData(system, &a, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id) == noErr
    }

    static func observeOutputChanges(_ handler: @escaping () -> Void) -> AudioChangeObservation {
        AudioChangeObservation(selectors: [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice],
                               handler: handler)
    }
}

final class AudioChangeObservation {
    private var registered: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    fileprivate init(selectors: [AudioObjectPropertySelector], handler: @escaping () -> Void) {
        for selector in selectors {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
            let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block) == noErr {
                registered.append((address, block))
            }
        }
    }

    deinit {
        for (address, block) in registered {
            var address = address
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
        }
    }
}

struct WiredOutputPolicy: Equatable {
    enum Action: Equatable {
        case none
        case switchTo(uid: String)
        case restore(uid: String)
    }

    private(set) var previousUID: String?
    private(set) var applied = false

    private(set) var userOverrode = false

    mutating func evaluate(enabled: Bool, usbPresent: Bool, headphoneUID: String?, defaultUID: String?) -> Action {
        if !usbPresent && !applied { userOverrode = false }

        if applied {

            if let headphoneUID, let defaultUID, defaultUID != headphoneUID {
                applied = false
                previousUID = nil
                userOverrode = true
                return .none
            }
            if !enabled || !usbPresent {
                let previous = previousUID
                applied = false
                previousUID = nil
                if !usbPresent { userOverrode = false }
                if let previous, previous != defaultUID { return .restore(uid: previous) }
            }
            return .none
        }

        if !usbPresent { return .none }
        guard enabled, !userOverrode, let headphoneUID else { return .none }
        if defaultUID == headphoneUID { return .none }
        previousUID = defaultUID
        applied = true
        return .switchTo(uid: headphoneUID)
    }

    mutating func switchFailed() {
        applied = false
        previousUID = nil
    }
}

@MainActor
@Observable
final class WiredOutputController {
    static let shared = WiredOutputController()

    static let defaultsKey = "wired.useAsOutput"

    var enabled: Bool = UserDefaults.standard.bool(forKey: WiredOutputController.defaultsKey) {
        didSet {
            guard enabled != oldValue else { return }
            UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
            evaluate()
        }
    }

    @ObservationIgnored private var policy = WiredOutputPolicy()
    @ObservationIgnored private var usbPresent = false
    @ObservationIgnored private var observation: AudioChangeObservation?

    private init() {}

    func usbPresenceChanged(_ present: Bool) {
        usbPresent = present
        evaluate()
    }

    private func evaluate() {

        let needed = usbPresent && (enabled || policy.applied)
        if needed, observation == nil {
            observation = AudioDevices.observeOutputChanges { [weak self] in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        } else if !needed, !usbPresent {
            observation = nil
        }
        guard enabled || policy.applied else { return }

        let headphone = usbPresent ? AudioDevices.usbOutputDevice() : nil
        let current = AudioDevices.defaultOutputDevice()
        switch policy.evaluate(enabled: enabled, usbPresent: usbPresent,
                               headphoneUID: headphone?.uid, defaultUID: current?.uid) {
        case .none:
            break
        case .switchTo:
            if let headphone, AudioDevices.setDefaultOutputDevice(headphone) { break }
            policy.switchFailed()
        case .restore(let uid):

            if let previous = AudioDevices.outputDevice(uid: uid) { AudioDevices.setDefaultOutputDevice(previous) }
        }
    }
}
