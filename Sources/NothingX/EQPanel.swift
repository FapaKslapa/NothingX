import SwiftUI

struct EQPanel: View {
    let bands: [EQBand]
    let onChange: (Int, Float) -> Void
    let onEnd: () -> Void
    @State private var selected: Int?

    private var readout: String {
        guard let band = bands.first(where: { $0.id == selected }) else { return " " }
        let freq = band.freq >= 1000 ? String(format: "%.1f kHz", band.freq / 1000) : "\(Int(band.freq)) Hz"
        return "\(freq)  \(String(format: "%+.1f dB", band.gain))"
    }

    var body: some View {
        VStack(spacing: 16) {
            EQCurveView(bands: bands, selected: selected)
            HStack(alignment: .top, spacing: 0) {
                axis
                ForEach(bands) { band in
                    EQBandColumn(gain: band.gain, freq: band.freq, selected: band.id == selected) {
                        selected = band.id
                    } onChange: {
                        onChange(band.id, $0)
                    } onEnd: {
                        onEnd()
                        selected = nil
                    }
                    .frame(maxWidth: .infinity)
                }
                axis
            }
            Text(verbatim: readout).ntLabel(NTColor.secondary)
        }
    }

    private var axis: some View {
        VStack {
            Text(verbatim: "+")
            Spacer()
            Text(verbatim: "0")
            Spacer()
            Text(verbatim: "−")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(NTColor.secondary)
        .frame(width: 14, height: 200)
    }
}
