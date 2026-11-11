import SwiftUI

struct MenuBarPanel: View {
    @Environment(HeadphoneModel.self) private var model
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.openWindow) private var openWindow

    private var connected: Bool { model.connection == .connected }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if connected {
                Segmented(options: ANCKind.allCases.map { ($0, $0.label) }, selection: model.ancRaw.map(ANCState.kind(of:))) {
                    model.setANCKind($0)
                }
                if model.macAnchored {
                    Button { model.recenterHead() } label: { ActionText("[Recenter]", NTColor.primary) }.buttonStyle(.plain)
                }
            }
            NowPlayingTile(service: model.nowPlaying)
            actions
        }
        .padding(18)
        .frame(width: 360)
        .background(NTBackground())
        .foregroundStyle(NTColor.primary)
    }

    private var header: some View {
        HStack(spacing: 14) {
            if connected {
                BatteryGauge(readings: model.batteryParts, compact: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: connected ? model.deviceName : String(localized: "Headphone not connected"))
                    .font(.system(size: 15, weight: .semibold))
                if !connected { statusLine }
            }
            Spacer(minLength: 0)
            DeviceIllustration(deviceName: model.deviceName, size: 84)
                .frame(width: 96, height: 84)
        }
    }

    private var statusLine: some View {
        Group {
            if model.connection == .permissionDenied {
                Button { BluetoothGate.openSettings() } label: { ActionText("[Open Bluetooth settings]", NTColor.primary) }
                    .buttonStyle(.plain)
            } else {
                Text("Searching for headphone").ntLabel(NTColor.disabled)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            PillButton(title: "Open", prominent: true) { open(settings: false) }
            PillButton(title: "Settings") { open(settings: true) }
            Spacer(minLength: 0)
            PillButton(title: "Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    private func open(settings: Bool) {
        navigation.showSettings = settings
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }
}
