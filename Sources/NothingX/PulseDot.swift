import SwiftUI

struct PulseDot: View {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            if active && !reduceMotion {
                Circle()
                    .fill(NTColor.display.opacity(0.5))
                    .scaleEffect(expanded ? 2.6 : 1)
                    .opacity(expanded ? 0 : 1)
            }
            Circle()
                .fill(active ? NTColor.display : Color.clear)
                .overlay(Circle().stroke(active ? Color.clear : NTColor.disabled, lineWidth: 1))
        }
        .frame(width: 7, height: 7)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { expanded = true }
        }
    }
}
