import SwiftUI

struct ContentView: View {
    @Environment(HeadphoneModel.self) private var model
    @Environment(AppNavigation.self) private var navigation
    @State private var showDevices = false

    private var connected: Bool { model.connection == .connected }

    var body: some View {
        VStack(spacing: 0) {
            if navigation.showSettings {
                SettingsPanel().windowInset().transition(.opacity)
            } else if showDevices || (!connected && !model.isWired) {
                DevicesView { showDevices = false }.windowInset().transition(.opacity)
            } else {
                Dashboard().windowInset()
            }
        }
        .animation(.snappy(duration: 0.25), value: navigation.showSettings)
        .animation(.snappy(duration: 0.25), value: showDevices)
        .overlay(alignment: .top) {
            ZStack(alignment: .topTrailing) {
                WindowDragHandle().frame(height: 64)
                topBar.padding(.horizontal, 32).padding(.top, 14)
            }
        }
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
        .background(NTBackground())
        .foregroundStyle(NTColor.primary)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !model.status.isEmpty {
                Text(verbatim: model.status).ntLabel(model.status == "[OK]" ? NTColor.secondary : NTColor.accent)
            }
            if !connected || model.isWired { statusBadge.padding(.trailing, 10) }
            roundButton("rectangle.stack", label: "Your devices") {
                navigation.showSettings = false
                showDevices.toggle()
            }
            roundButton(navigation.showSettings ? "xmark" : "gearshape", label: "Settings") { navigation.showSettings.toggle() }
        }
    }

    private func roundButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NTColor.primary)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
                .ntGlass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            PulseDot(active: connected)
            statusText.ntLabel(NTColor.disabled)
        }
    }

    private var statusText: Text {
        if model.isWired { return Text("Wired (USB)") }
        switch model.connection {
        case .connected: return Text("Connected")
        case .connecting: return Text("Connecting…")
        case .searching: return Text("Searching for headphone")
        case .permissionPending: return Text("Waiting for Bluetooth permission…")
        case .permissionDenied: return Text("Bluetooth access denied")
        }
    }
}
