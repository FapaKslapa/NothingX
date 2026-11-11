import SwiftUI

struct BatteryGauge: View {
    let readings: [BatteryReading]
    var compact = false

    private var ringSize: CGFloat { compact ? (readings.count > 1 ? 44 : 56) : (readings.count > 1 ? 58 : 88) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if readings.isEmpty {
                BatteryRing(level: nil, charging: false, size: ringSize)
            } else {
                ForEach(readings) { reading in
                    VStack(spacing: 8) {
                        BatteryRing(level: reading.level, charging: reading.charging, size: ringSize)
                        if readings.count > 1 {
                            Text(reading.part.label).ntLabel(NTColor.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct BatteryRing: View {
    let level: Int?
    let charging: Bool
    let size: CGFloat

    private var tint: Color { (level ?? 100) <= 15 ? NTColor.accent : Color.white.opacity(0.92) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: size * 0.09)
            Circle()
                .trim(from: 0, to: CGFloat(level ?? 0) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(verbatim: level.map { "\($0)" } ?? "–")
                    .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if charging {
                    Image(systemName: "bolt.fill").font(.system(size: size * 0.14)).foregroundStyle(NTColor.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Battery"))
        .accessibilityValue(Text(verbatim: level.map { "\($0)%" } ?? "—"))
    }
}

extension BatteryReading.Part {
    var label: String {
        switch self {
        case .left: String(localized: "Left")
        case .right: String(localized: "Right")
        case .charger: String(localized: "Case")
        case .headphone: String(localized: "Headphone")
        }
    }
}
