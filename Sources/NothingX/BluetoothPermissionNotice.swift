import SwiftUI

struct BluetoothPermissionNotice: View {
    @Environment(HeadphoneModel.self) private var model

    var body: some View {
        switch model.connection {
        case .permissionPending:
            VStack(alignment: .leading, spacing: 10) {
                Text("Waiting for Bluetooth permission…").ntLabel(NTColor.primary)
                Text("Answer the macOS prompt. It may be on another display.")
                    .ntLabel(NTColor.disabled)
            }
        case .permissionDenied:
            VStack(alignment: .leading, spacing: 10) {
                Text("Bluetooth access denied").ntLabel(NTColor.primary)
                Text("Allow it in Privacy & Security › Bluetooth.")
                    .ntLabel(NTColor.disabled)
                Button { BluetoothGate.openSettings() } label: {
                    ActionText("[Open Bluetooth settings]", NTColor.secondary)
                }
                .buttonStyle(.plain)
            }
        case .searching, .connecting, .connected:
            EmptyView()
        }
    }
}
