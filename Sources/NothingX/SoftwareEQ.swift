import AVFoundation

enum SoftwareEQ {

    static let frequencies: [Float] = [55, 110, 220, 440, 1320, 3300, 6600, 13200]
    static let defaultQ: Float = 1

    static let gainRange: ClosedRange<Float> = -12...12

    struct BandParameters: Equatable {
        var filterType: AVAudioUnitEQFilterType
        var frequency: Float

        var bandwidth: Float
        var gain: Float
    }

    static func filterType(_ type: UInt8) -> AVAudioUnitEQFilterType {
        switch type {
        case 0: .lowShelf
        case 2: .highShelf
        default: .parametric
        }
    }

    static func bandwidth(q: Float) -> Float {
        guard q.isFinite, q > 0 else { return 5 }
        let octaves = 2 / Float(M_LN2) * asinh(1 / (2 * q))
        return min(max(octaves, 0.05), 5)
    }

    static func clampedGain(_ gain: Float) -> Float {
        gain.isFinite ? min(max(gain, gainRange.lowerBound), gainRange.upperBound) : 0
    }

    static func parameters(for band: EQBand, sampleRate: Double = 48_000) -> BandParameters {
        let nyquist = Float(sampleRate / 2) * 0.95
        let frequency = band.freq.isFinite ? min(max(band.freq, 20), nyquist) : 1000
        return BandParameters(filterType: filterType(band.type), frequency: frequency,
                              bandwidth: bandwidth(q: band.q), gain: clampedGain(band.gain))
    }

    static func headroom(_ gains: [Float]) -> Float {
        -max(0, gains.map(clampedGain).max() ?? 0)
    }

    static func step(_ current: [Float], toward target: [Float], maxStep: Float) -> [Float] {
        guard current.count == target.count else { return target }
        return zip(current, target).map { c, t in
            abs(t - c) <= maxStep ? t : c + (t > c ? maxStep : -maxStep)
        }
    }

    static func profile(gains: [Float]) -> EQProfile {
        EQProfile(profile: 0, gain: 0, bands: frequencies.enumerated().map { i, f in
            EQBand(id: i, type: 1, gain: i < gains.count ? clampedGain(gains[i]) : 0, freq: f, q: defaultQ)
        })
    }

    static func preset(matching gains: [Float]) -> EQPreset {
        EQPreset.allCases.first { preset in
            guard let curve = preset.gains, curve.count == gains.count else { return false }
            return zip(curve, gains).allSatisfy { abs($0 - $1) < 0.05 }
        } ?? .custom
    }
}

enum EQPath: Equatable {

    case hardware

    case software

    static func active(isWired: Bool) -> EQPath { isWired ? .software : .hardware }
}

enum SoftwareEQPolicy {
    enum Action: Equatable { case start, stop, none }

    static func shouldRun(enabled: Bool, wired: Bool, macAnchorActive: Bool) -> Bool {
        enabled && wired && !macAnchorActive
    }

    static func action(enabled: Bool, wired: Bool, macAnchorActive: Bool, active: Bool) -> Action {
        let run = shouldRun(enabled: enabled, wired: wired, macAnchorActive: macAnchorActive)
        if run && !active { return .start }
        if !run && active { return .stop }
        return .none
    }
}
