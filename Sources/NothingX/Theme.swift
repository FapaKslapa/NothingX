import SwiftUI

enum NTColor {
    static let background = Color.black
    static let display = Color.white
    static let primary = Color.white.opacity(0.9)
    static let secondary = Color.white.opacity(0.6)
    static let disabled = Color.white.opacity(0.4)
    static let accent = Color(red: 0.843, green: 0.098, blue: 0.129)
}

extension Text {
    func ntLabel(_ color: Color = NTColor.secondary) -> some View {
        font(.system(size: 12, weight: .medium)).foregroundStyle(color)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var trailing: String = ""

    var body: some View {
        HStack {
            Text(title).ntLabel()
            Spacer()
            if !trailing.isEmpty { Text(verbatim: trailing).ntLabel(NTColor.disabled) }
        }
    }
}

struct Segmented<ID: Hashable>: View {
    let options: [(id: ID, label: String)]
    let selection: ID?
    let onSelect: (ID) -> Void
    @State private var hovered: Int?
    @Namespace private var thumb
    @Environment(\.ntAccent) private var accent

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let active = option.id == selection
                Button { onSelect(option.id) } label: {
                    Text(verbatim: option.label)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(active ? NTColor.display : NTColor.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background { segmentBackground(active: active, hovered: hovered == index) }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { inside in hovered = inside ? index : (hovered == index ? nil : hovered) }
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .animation(.snappy(duration: 0.25), value: selection)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private func segmentBackground(active: Bool, hovered: Bool) -> some View {
        if active {
            Color.clear
                .ntGlass(Capsule(), tint: accent.opacity(0.35), interactive: true)
                .matchedGeometryEffect(id: "thumb", in: thumb)
        } else {
            Capsule().fill(hovered ? Color.white.opacity(0.08) : Color.clear)
        }
    }
}
