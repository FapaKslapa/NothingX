import SwiftUI

struct EQCurveView: View {
    let bands: [EQBand]
    let selected: Int?
    @Environment(\.ntAccent) private var accent

    private static let marks: [(freq: Double, label: String)] = [
        (20, "20"), (50, "50"), (100, "100"), (500, "500"), (1000, "1K"), (5000, "5K"), (10000, "10K"), (20000, "20K"),
    ]
    private static let inset: CGFloat = 16
    private static let span = 15.0

    private func x(_ freq: Double, _ width: CGFloat) -> CGFloat {
        Self.inset + CGFloat(log10(freq / 20) / 3) * (width - 2 * Self.inset)
    }

    private func y(_ db: Double, _ height: CGFloat) -> CGFloat {
        height / 2 - CGFloat(db / Self.span) * height / 2
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let curve = Path { p in
                    for i in 0...120 {
                        let f = 20 * pow(1000, Double(i) / 120)
                        let point = CGPoint(x: x(f, w), y: y(EQResponse.db(at: f, bands: bands), h))
                        i == 0 ? p.move(to: point) : p.addLine(to: point)
                    }
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.06))
                    ForEach(Self.marks, id: \.freq) { mark in
                        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1).position(x: x(mark.freq, w), y: h / 2)
                    }
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).position(x: w / 2, y: h / 2)
                    curve
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    curve
                        .applying(.identity)
                        .trimmedPath(from: 0, to: 1)
                        .path(in: CGRect(origin: .zero, size: geo.size))
                        .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom))
                        .mask(
                            Path { p in
                                p.addPath(curve)
                                p.addLine(to: CGPoint(x: x(20000, w), y: h))
                                p.addLine(to: CGPoint(x: x(20, w), y: h))
                                p.closeSubpath()
                            }
                        )
                    ForEach(bands) { band in
                        let isSelected = band.id == selected
                        Circle()
                            .fill(isSelected ? accent : Color.white.opacity(0.6))
                            .frame(width: isSelected ? 9 : 8, height: isSelected ? 9 : 8)
                            .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 2))
                            .position(x: x(Double(band.freq), w), y: y(EQResponse.db(at: Double(band.freq), bands: bands), h))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .animation(.snappy(duration: 0.2), value: bands)
            }
            .frame(height: 128)
            GeometryReader { geo in
                ForEach(Self.marks, id: \.freq) { mark in
                    Text(verbatim: mark.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NTColor.secondary)
                        .position(x: x(mark.freq, geo.size.width), y: 7)
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }
}
