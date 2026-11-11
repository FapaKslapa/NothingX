import SwiftUI

struct SpatialAudioCard: View {
    @Environment(HeadphoneModel.self) private var model

    private enum Choice { case off, headphone, mac }

    private var connected: Bool { model.connection == .connected }

    private var choice: Choice? {
        if model.macAnchored { return .mac }
        guard let state = model.spatial else { return nil }
        return state.on ? .headphone : .off
    }

    private var caption: LocalizedStringKey? {
        switch choice {
        case .off: "Standard stereo sound, no spatial processing."
        case .headphone: "The headphone creates the spatial effect. Head tracking keeps it steady when you turn."
        default: nil
        }
    }

    var body: some View {
        let state = model.spatial
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Spatial audio")
            Segmented(
                options: [(Choice.off, String(localized: "Off")),
                          (.headphone, String(localized: "Headphone")),
                          (.mac, String(localized: "Fixed to Mac"))],
                selection: choice
            ) { select($0, state) }
            if let caption {
                Text(caption).font(.system(size: 12)).foregroundStyle(NTColor.disabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if choice == .headphone {
                HStack {
                    Text("Head tracking").ntLabel()
                    Spacer()
                    NTToggle(isOn: state?.headTracking == true) { model.setSpatial(on: true, headTracking: $0) }
                }
                Text("EQ presets are disabled while spatial audio is on.").ntLabel(NTColor.disabled)
            }
            if choice == .mac { macControls }
        }
        .ntCard()
        .disabled(!connected || state == nil)
        .opacity(connected ? 1 : 0.4)
    }

    private func select(_ choice: Choice, _ state: SpatialState?) {
        switch choice {
        case .off:
            if model.macAnchored { model.setMacAnchored(false) }
            model.setSpatial(on: false, headTracking: false)
        case .headphone:
            if model.macAnchored { model.setMacAnchored(false) }
            model.setSpatial(on: true, headTracking: state?.headTracking ?? true)
        case .mac:
            model.setMacAnchored(true)
        }
    }

    private var macControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { model.recenterHead() } label: { ActionText("[Recenter]", NTColor.primary) }
                    .buttonStyle(.plain)
                Spacer()
                Text(verbatim: model.anchorDetail).ntLabel(NTColor.disabled)
            }
            HStack(spacing: 14) {
                Text("Sensitivity").ntLabel()
                Slider(value: Binding(get: { model.anchorSensitivity }, set: { model.anchorSensitivity = $0 }),
                       in: 0.5...1.5, step: 0.05)
                    .controlSize(.small)
                Text(verbatim: String(format: "%.2f×", model.anchorSensitivity))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NTColor.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            Text("Sound stays fixed in front of you, where the Mac is. Look at the Mac and press Recenter if it drifts.")
                .font(.system(size: 12))
                .foregroundStyle(NTColor.disabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
