import SwiftUI

struct PillButton: View {
    let title: LocalizedStringResource
    var prominent = false
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(verbatim: String(localized: title).trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(role == .destructive ? NTColor.accent : NTColor.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .contentShape(Capsule())
                .ntGlass(Capsule(), tint: prominent ? Color.white.opacity(0.18) : nil, interactive: true)
        }
        .buttonStyle(.plain)
    }
}
