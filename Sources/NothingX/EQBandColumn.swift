import SwiftUI

struct EQBandColumn: View {
    let gain: Float
    let freq: Float
    let selected: Bool
    var range: ClosedRange<Float> = -12...12
    let onBegin: () -> Void
    let onChange: (Float) -> Void
    let onEnd: () -> Void
    @Environment(\.ntAccent) private var accent

    private static let height: CGFloat = 200
    private static let inset: CGFloat = 20
    private static let marks: [Float] = [12, 6, 0, -6, -12]

    private var freqLabel: String {
        freq >= 1000 ? String(format: "%.1fK", freq / 1000).replacingOccurrences(of: ".0K", with: "K") : "\(Int(freq))"
    }

    private func y(_ db: Float) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        return Self.inset + CGFloat((range.upperBound - db) / span) * (Self.height - 2 * Self.inset)
    }

    private func covered(_ mark: Float) -> Bool {
        gain == 0 ? false : (min(gain, 0)...max(gain, 0)).contains(mark)
    }

    private func gain(at location: CGFloat) -> Float {
        let t = min(max((location - Self.inset) / (Self.height - 2 * Self.inset), 0), 1)
        let raw = range.upperBound - Float(t) * (range.upperBound - range.lowerBound)
        return (raw * 2).rounded() / 2
    }

    var body: some View {
        ZStack(alignment: .top) {
            Capsule().fill(Color.white.opacity(selected ? 0.08 : 0))
            Capsule().stroke(Color.white.opacity(selected ? 0 : 0.2), lineWidth: 2)
            ForEach(Self.marks.filter { !covered($0) }, id: \.self) { mark in
                Circle().fill(Color.white.opacity(0.08)).frame(width: 14, height: 14).offset(y: y(mark) - 7)
            }
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 22, height: abs(y(gain) - y(0)))
                .offset(y: min(y(gain), y(0)))
            Circle()
                .fill(selected ? accent : Color.white.opacity(0.95))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white.opacity(selected ? 0.45 : 0), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                .offset(y: y(gain) - 12)
        }
        .frame(width: 40, height: Self.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    onBegin()
                    onChange(gain(at: drag.location.y))
                }
                .onEnded { _ in onEnd() }
        )
        .animation(.snappy(duration: 0.18), value: gain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(freqLabel) Hz"))
        .accessibilityValue(Text(verbatim: String(format: "%+.1f dB", gain)))
        .accessibilityAdjustableAction { direction in
            onBegin()
            onChange(min(max(gain + (direction == .increment ? 0.5 : -0.5), range.lowerBound), range.upperBound))
            onEnd()
        }
    }
}
