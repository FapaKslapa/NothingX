import Foundation

enum NT {

    static let serviceUUID: [UInt8] = [0xAE, 0xAC, 0x4A, 0x03, 0xDF, 0xF5, 0x49, 0x8F,
                                       0x84, 0x3A, 0x34, 0x48, 0x7C, 0xF1, 0x33, 0xEB]

    enum Cmd {
        static let readDeviceInfo: UInt16 = 0xC006
        static let readBattery: UInt16 = 0xC007
        static let readANC: UInt16 = 0xC01E
        static let readEQPreset: UInt16 = 0xC01F
        static let readFirmware: UInt16 = 0xC042
        static let readCustomEQ: UInt16 = 0xC04D
        static let readBassBoost: UInt16 = 0xC04E
        static let readSpatial: UInt16 = 0xC04F
        static let readGestures: UInt16 = 0xC018
        static let setANC: UInt16 = 0xF00F
        static let setEQPreset: UInt16 = 0xF010
        static let setCustomEQ: UInt16 = 0xF050
        static let setBassBoost: UInt16 = 0xF051
        static let setSpatial: UInt16 = 0xF052
        static let setGestures: UInt16 = 0xF003

        static let startHeadStream: UInt16 = 0xC058
        static let notifyANC: UInt16 = 0xE003
        static let notifyHeadPose: UInt16 = 0xE015
    }
}

struct Frame {
    var cmd: UInt16
    var opId: UInt8
    var payload: [UInt8]
}

enum Codec {

    static func crc16(_ bytes: some Sequence<UInt8>) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
        }
        return crc
    }

    static func encode(cmd: UInt16, opId: UInt8, payload: [UInt8]) -> [UInt8] {
        let n = UInt16(payload.count)
        var out: [UInt8] = [0x55, 0x60, 0x01, UInt8(cmd & 0xFF), UInt8(cmd >> 8),
                            UInt8(n & 0xFF), UInt8(n >> 8), opId] + payload
        let crc = crc16(out)
        out += [UInt8(crc & 0xFF), UInt8(crc >> 8)]
        return out
    }
}

struct FrameParser {
    private var buffer: [UInt8] = []

    mutating func reset() { buffer.removeAll() }

    mutating func feed(_ data: [UInt8]) -> [Frame] {
        buffer += data
        var frames: [Frame] = []
        while true {
            guard let start = buffer.firstIndex(of: 0x55) else { buffer.removeAll(); break }
            if start > 0 { buffer.removeFirst(start) }

            if buffer.count < 10 { break }
            let len = Int(buffer[5]) | Int(buffer[6]) << 8
            if len > 2048 { buffer.removeFirst(); continue }
            let total = 8 + len + 2
            if buffer.count < total { break }
            let body = Array(buffer[0..<(total - 2)])
            let crc = UInt16(buffer[total - 2]) | UInt16(buffer[total - 1]) << 8
            if Codec.crc16(body) != crc { buffer.removeFirst(); continue }
            frames.append(Frame(cmd: UInt16(buffer[3]) | UInt16(buffer[4]) << 8,
                                opId: buffer[7],
                                payload: Array(buffer[8..<(total - 2)])))
            buffer.removeFirst(total)
        }
        return frames
    }
}

enum ANCKind: CaseIterable {
    case anc, transparency, off
    var label: String {
        switch self {
        case .anc: String(localized: "ANC")
        case .transparency: String(localized: "Transparency")
        case .off: String(localized: "Off")
        }
    }
}

enum ANCLevel: UInt8, CaseIterable {
    case high = 1, mid = 2, low = 3, adaptive = 4
    var label: String {
        switch self {
        case .high: String(localized: "High")
        case .mid: String(localized: "Mid")
        case .low: String(localized: "Low")
        case .adaptive: String(localized: "Adaptive")
        }
    }
}

enum ANCState {
    static let off: UInt8 = 5
    static let transparency: UInt8 = 7

    static func kind(of raw: UInt8) -> ANCKind {
        switch raw {
        case off: .off
        case transparency: .transparency
        default: .anc
        }
    }
}

enum EQPreset: CaseIterable {
    case balanced, bass, treble, voice, custom

    var label: String {
        switch self {
        case .balanced: String(localized: "Balanced")
        case .bass: String(localized: "More bass")
        case .treble: String(localized: "More treble")
        case .voice: String(localized: "Voice")
        case .custom: String(localized: "Custom")
        }
    }

    var gains: [Float]? {
        switch self {
        case .balanced: [0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: [6, 5, 3, 1, 0, 0, 0, 0]
        case .treble: [0, 0, 0, 0, 1, 3, 5, 6]
        case .voice: [-3, -2, 0, 2, 4, 3, 0, -2]
        case .custom: nil
        }
    }

    static let deviceBalanced: UInt8 = 0
    static let deviceCustom: UInt8 = 5
}

struct EQBand: Identifiable, Equatable {
    var id: Int
    var type: UInt8
    var gain: Float
    var freq: Float
    var q: Float
}

struct EQProfile: Equatable {
    var profile: UInt8
    var gain: Float
    var bands: [EQBand]

    private static func float(_ p: [UInt8], _ o: Int) -> Float {
        Float(bitPattern: UInt32(p[o]) | UInt32(p[o + 1]) << 8 | UInt32(p[o + 2]) << 16 | UInt32(p[o + 3]) << 24)
    }

    private static func bytes(_ f: Float) -> [UInt8] {
        let b = f.bitPattern
        return [UInt8(b & 0xFF), UInt8((b >> 8) & 0xFF), UInt8((b >> 16) & 0xFF), UInt8(b >> 24)]
    }

    static func decode(_ p: [UInt8]) -> EQProfile? {
        guard p.count >= 6 else { return nil }
        let n = Int(p[1])
        guard p.count >= 6 + n * 13 else { return nil }
        var bands: [EQBand] = []
        var o = 6
        for i in 0..<n {
            bands.append(EQBand(id: i, type: p[o], gain: float(p, o + 1), freq: float(p, o + 5), q: float(p, o + 9)))
            o += 13
        }
        return EQProfile(profile: p[0], gain: float(p, 2), bands: bands)
    }

    func encode() -> [UInt8] {
        var out: [UInt8] = [profile, UInt8(bands.count)] + Self.bytes(gain)
        for b in bands { out += [b.type] + Self.bytes(b.gain) + Self.bytes(b.freq) + Self.bytes(b.q) }
        return out
    }
}

struct SpatialState: Equatable {
    var on: Bool
    var headTracking: Bool

    static func decode(_ p: [UInt8]) -> SpatialState? {
        guard let first = p.first else { return nil }
        return SpatialState(on: first != 0, headTracking: p.count > 1 && p[1] != 0)
    }

    func encode() -> [UInt8] { [on ? 1 : 0, headTracking ? 1 : 0] }
}

struct GestureBinding: Identifiable, Equatable {
    var side: UInt8
    var button: UInt8
    var gesture: UInt8
    var action: UInt8

    var id: Int { Int(side) << 16 | Int(button) << 8 | Int(gesture) }

    static func decodeTable(_ p: [UInt8]) -> [GestureBinding] {
        guard let count = p.first else { return [] }
        var rows: [GestureBinding] = []
        for i in 0..<Int(count) {
            let o = 1 + 4 * i
            guard o + 4 <= p.count else { break }
            rows.append(GestureBinding(side: p[o], button: p[o + 1], gesture: p[o + 2], action: p[o + 3]))
        }
        return rows
    }

    func encodeSet() -> [UInt8] { [1, side, button, gesture, action] }

    static func controlName(_ b: UInt8) -> String {
        switch b {
        case 0x01: String(localized: "Roller")
        case 0x0A: String(localized: "Button")
        default: String(format: String(localized: "Control 0x%02X"), b)
        }
    }

    static func sideName(_ side: UInt8) -> String? {
        switch side {
        case 0x02: String(localized: "Left earbud")
        case 0x03: String(localized: "Right earbud")
        default: nil
        }
    }

    static func gestureName(_ g: UInt8) -> String {
        switch g {
        case 0x01: String(localized: "Press")
        case 0x02: String(localized: "Single press")
        case 0x03: String(localized: "Double press")
        case 0x07: String(localized: "Triple press")
        case 0x09: String(localized: "Press and hold")
        default: String(format: String(localized: "Gesture 0x%02X"), g)
        }
    }

    static let knownActions: [UInt8] = [0x01, 0x09, 0x08, 0x16, 0x0B]

    static func actionName(_ a: UInt8) -> String {
        switch a {
        case 0x01: String(localized: "None")
        case 0x08: String(localized: "Next track")
        case 0x09: String(localized: "Play / pause")
        case 0x16: String(localized: "Previous track")
        case 0x0B: String(localized: "Noise control")
        default: String(format: String(localized: "Action 0x%02X"), a)
        }
    }
}

extension NT.Cmd {
    static let readLowLatency: UInt16 = 0xC041
    static let readCodec: UInt16 = 0xC029
    static let readDualConnection: UInt16 = 0xC027
    static let readAdaptiveANC: UInt16 = 0xC055

    static let readFeatureFlags: UInt16 = 0xC00E
    static let setLowLatency: UInt16 = 0xF040
    static let setCodec: UInt16 = 0xF01C
    static let setDualConnection: UInt16 = 0xF01A
    static let setAdaptiveANC: UInt16 = 0xF059
    static let setFeatureFlag: UInt16 = 0xF004

    static let findHeadphone: UInt16 = 0xF002
}

enum DeviceSetting {

    static func decodeFlag(_ p: [UInt8]) -> Bool? {
        p.first.map { $0 != 0 }
    }

    static func encodeFlag(_ on: Bool) -> [UInt8] { [on ? 1 : 0] }

    static func decodeLowLatency(_ p: [UInt8]) -> Bool? {
        switch p.first {
        case 1: true
        case 2: false
        default: nil
        }
    }

    static func encodeLowLatency(_ on: Bool) -> [UInt8] { [on ? 1 : 2] }
}

enum AudioCodec: UInt8, CaseIterable {
    case standard = 0
    case ldac = 2

    static func decode(_ p: [UInt8]) -> AudioCodec? { p.first.flatMap(AudioCodec.init(rawValue:)) }

    func encode() -> [UInt8] { [rawValue] }

    var label: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .ldac: String(localized: "LDAC")
        }
    }
}

struct DeviceFeatureTable: Equatable {
    struct Entry: Equatable {
        var id: UInt8
        var flag: UInt8
    }

    var entries: [Entry]

    static let inEarDetection: UInt8 = 0x01

    static func decode(_ p: [UInt8]) -> DeviceFeatureTable? {
        guard let count = p.first else { return nil }
        var entries: [Entry] = []
        for i in 0..<Int(count) {
            let o = 1 + 2 * i
            guard o + 2 <= p.count else { break }
            entries.append(Entry(id: p[o], flag: p[o + 1]))
        }
        return DeviceFeatureTable(entries: entries)
    }

    func flag(_ id: UInt8) -> Bool? {
        entries.first(where: { $0.id == id }).map { $0.flag != 0 }
    }

    var inEarDetectionOn: Bool? { flag(Self.inEarDetection) }

    static func encodeSet(feature: UInt8, on: Bool) -> [UInt8] { [1, feature, on ? 1 : 0] }

    static func encodeInEarDetection(on: Bool) -> [UInt8] { encodeSet(feature: inEarDetection, on: on) }
}

enum FindMyHeadphone {
    static let side: UInt8 = 0x06

    static func payload(on: Bool) -> [UInt8] { [side, on ? 1 : 0] }
}

struct BatteryReading: Equatable, Identifiable {
    enum Part: UInt8 {
        case left = 2, right = 3, charger = 4, headphone = 6
    }

    var part: Part
    var level: Int
    var charging: Bool
    var id: UInt8 { part.rawValue }

    static func decode(_ payload: [UInt8]) -> [BatteryReading] {
        guard let count = payload.first else { return [] }
        return (0..<Int(count)).compactMap { index in
            let offset = 1 + index * 2
            guard offset + 1 < payload.count, let part = Part(rawValue: payload[offset]) else { return nil }
            let raw = payload[offset + 1]
            return BatteryReading(part: part, level: Int(raw & 0x7F), charging: raw & 0x80 != 0)
        }
    }
}
