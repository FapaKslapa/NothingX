import SwiftUI

struct IconActionButton: View {
    let symbol: String
    let title: LocalizedStringKey
    var prominent = false
    var destructive = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(destructive ? NTColor.accent : (prominent ? Color.black : NTColor.primary))
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
                    .background(Circle().fill(prominent ? Color.white.opacity(0.92) : Color.clear))
                    .ntGlass(Circle(), tint: prominent ? nil : Color.white.opacity(0.04), interactive: true)
                    .scaleEffect(hovered ? 1.06 : 1)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NTColor.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.snappy(duration: 0.18), value: hovered)
    }
}
