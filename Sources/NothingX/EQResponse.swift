import Foundation

enum EQResponse {
    static func db(at freq: Double, bands: [EQBand], sampleRate: Double = 48_000) -> Double {
        bands.reduce(0) { $0 + magnitude(of: $1, at: freq, sampleRate: sampleRate) }
    }

    private static func magnitude(of band: EQBand, at freq: Double, sampleRate: Double) -> Double {
        guard band.gain != 0 else { return 0 }
        let a = pow(10, Double(band.gain) / 40)
        let w0 = 2 * Double.pi * Double(band.freq) / sampleRate
        let cosW0 = cos(w0)
        let q = max(Double(band.q), 0.1)
        let alpha = sin(w0) / (2 * q)
        let shelf = 2 * a.squareRoot() * (sin(w0) / 2) * 2.0.squareRoot()
        let c: (b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double)
        switch band.type {
        case 0:
            c = (a * ((a + 1) - (a - 1) * cosW0 + shelf), 2 * a * ((a - 1) - (a + 1) * cosW0),
                 a * ((a + 1) - (a - 1) * cosW0 - shelf),
                 (a + 1) + (a - 1) * cosW0 + shelf, -2 * ((a - 1) + (a + 1) * cosW0),
                 (a + 1) + (a - 1) * cosW0 - shelf)
        case 2:
            c = (a * ((a + 1) + (a - 1) * cosW0 + shelf), -2 * a * ((a - 1) + (a + 1) * cosW0),
                 a * ((a + 1) + (a - 1) * cosW0 - shelf),
                 (a + 1) - (a - 1) * cosW0 + shelf, 2 * ((a - 1) - (a + 1) * cosW0),
                 (a + 1) - (a - 1) * cosW0 - shelf)
        default:
            c = (1 + alpha * a, -2 * cosW0, 1 - alpha * a, 1 + alpha / a, -2 * cosW0, 1 - alpha / a)
        }
        let w = 2 * Double.pi * freq / sampleRate
        let cw = cos(w), c2w = cos(2 * w)
        let num = c.b0 * c.b0 + c.b1 * c.b1 + c.b2 * c.b2 + 2 * (c.b0 * c.b1 + c.b1 * c.b2) * cw + 2 * c.b0 * c.b2 * c2w
        let den = c.a0 * c.a0 + c.a1 * c.a1 + c.a2 * c.a2 + 2 * (c.a0 * c.a1 + c.a1 * c.a2) * cw + 2 * c.a0 * c.a2 * c2w
        return 10 * log10(num / den)
    }
}
