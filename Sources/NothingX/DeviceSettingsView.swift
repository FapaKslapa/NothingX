import SwiftUI

struct DeviceSettingsView: View {
    @Environment(HeadphoneModel.self) private var model

    private var connected: Bool { model.connection == .connected }

    private var tiles: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, value: Bool?, set: (Bool) -> Void)] {
        [("bolt.fill", "Low latency", "Reduces delay for video and games.", model.lowLatency, { model.setLowLatency($0) }),
         ("laptopcomputer.and.iphone", "Dual connection", "Stay connected to two devices at once.", model.dualConnection, { model.setDualConnection($0) }),
         ("waveform", "Adaptive ANC", "Adjusts noise cancelling to your surroundings.", model.adaptiveANC, { model.setAdaptiveANC($0) }),
         ("ear", "In-ear detection", "Pauses music when you take them off.", model.inEarDetection, { model.setInEarDetection($0) })]
            .filter { !connected || $0.value != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Device")
            LazyVGrid(columns: settingsColumns, spacing: 12) {
                ForEach(tiles.indices, id: \.self) { index in
                    let tile = tiles[index]
                    DeviceToggleTile(symbol: tile.symbol, title: tile.title, detail: tile.detail, value: tile.value, onSelect: tile.set)
                }
                if !DeviceKind(name: model.deviceName).isEarbuds {
                    ActionTile(symbol: model.findPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
                               title: "Find my headphone",
                               detail: "Plays a sound on the headphone so you can find it. Take it off first.",
                               buttonTitle: model.findPlaying ? "Stop" : "Play sound",
                               active: model.findPlaying) {
                        if model.findPlaying { model.stopFind() } else { model.startFindPulse() }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .ntCard()
        .disabled(!connected)
        .opacity(connected ? 1 : 0.4)
    }
}
