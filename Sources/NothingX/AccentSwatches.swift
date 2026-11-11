import SwiftUI

struct SwatchRow<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let color: (Option) -> Color
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 7) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    Circle()
                        .fill(color(option))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .frame(width: 16, height: 16)
                        .padding(3)
                        .overlay(Circle().stroke(Color.white.opacity(selection == option ? 0.9 : 0), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: label(option)))
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}

struct AccentSwatches: View {
    @AppStorage(AccentChoice.key) private var choice = AccentChoice.red

    var body: some View {
        SwatchRow(options: AccentChoice.allCases, selection: $choice, color: \.color, label: \.label)
    }
}

struct DeviceColorSwatches: View {
    @AppStorage(DeviceColor.key) private var choice = DeviceColor.black

    var body: some View {
        SwatchRow(options: DeviceColor.allCases, selection: $choice, color: \.color, label: \.label)
    }
}
