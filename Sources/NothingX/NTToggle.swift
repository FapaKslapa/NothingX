import SwiftUI

struct NTToggle: View {
    @Environment(\.ntAccent) private var accent
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(!isOn) } label: {
            Capsule()
                .fill(isOn ? accent : Color.white.opacity(0.14))
                .frame(width: 48, height: 28)
                .contentShape(Capsule())
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Color.white : Color.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .padding(3)
                }
                .animation(.snappy(duration: 0.2), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isToggle)
    }
}
