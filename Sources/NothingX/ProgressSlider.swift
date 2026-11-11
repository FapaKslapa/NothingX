import SwiftUI

struct ProgressSlider: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragging: Double?

    private var value: Double { dragging ?? position }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let fraction = duration > 0 ? min(max(value / duration, 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14)).frame(height: 5)
                    Capsule().fill(Color.white.opacity(0.9)).frame(width: geometry.size.width * fraction, height: 5)
                    Circle()
                        .fill(Color.white)
                        .frame(width: dragging == nil ? 10 : 14, height: dragging == nil ? 10 : 14)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .offset(x: geometry.size.width * fraction - (dragging == nil ? 5 : 7))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in dragging = min(max(drag.location.x / geometry.size.width, 0), 1) * duration }
                        .onEnded { _ in
                            if let dragging { onSeek(dragging) }
                            dragging = nil
                        }
                )
                .animation(.snappy(duration: 0.15), value: dragging == nil)
            }
            .frame(height: 20)
            HStack {
                Text(verbatim: Self.format(value))
                Spacer()
                Text(verbatim: Self.format(duration))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(NTColor.disabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playback position"))
        .accessibilityValue(Text(verbatim: "\(Self.format(value)) / \(Self.format(duration))"))
        .accessibilityAdjustableAction { direction in
            onSeek(min(max(position + (direction == .increment ? 10 : -10), 0), duration))
        }
    }

    static func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
