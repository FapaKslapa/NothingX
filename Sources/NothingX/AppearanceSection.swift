import SwiftUI

struct AppearanceSection: View {
    var body: some View {
        SettingsSection(title: "Appearance") {
            VStack(spacing: 12) {
                SettingsTile(symbol: "paintpalette", title: "Accent color",
                             detail: "Used for the equalizer, switches and selections.") {
                    AccentSwatches()
                }
                SettingsTile(symbol: "headphones", title: "Device color",
                             detail: "Picks the headphone picture shown in the app.") {
                    DeviceColorSwatches()
                }
            }
        }
    }
}
