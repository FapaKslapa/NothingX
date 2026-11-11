import SwiftUI

struct DevicesView: View {
    @Environment(HeadphoneModel.self) private var model
    let onOpen: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 340, maximum: 520), spacing: 20, alignment: .top)]

    var body: some View {
        CardScrollView(inset: Layout.topInset) {
            VStack(alignment: .leading, spacing: 24) {
                BluetoothPermissionNotice()
                Text("Your devices").font(.system(size: 26, weight: .semibold))
                if model.library.entries.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(model.library.entries) { entry in
                            DeviceCard(entry: entry, active: model.connection == .connected && entry.connected, onOpen: onOpen)
                        }
                    }
                }
            }
        }
        .onAppear { model.library.refresh() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No Nothing devices found").font(.system(size: 17, weight: .medium))
            Text("Pair a Nothing device in System Settings › Bluetooth, then it shows up here.")
                .font(.system(size: 13))
                .foregroundStyle(NTColor.secondary)
            PillButton(title: "Open Bluetooth settings", prominent: true) { BluetoothGate.openSettings() }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .ntCard()
    }
}

private struct DeviceCard: View {
    @Environment(HeadphoneModel.self) private var model
    @AppStorage(DeviceColor.key) private var deviceColor = DeviceColor.black
    let entry: DeviceLibrary.Entry
    let active: Bool
    let onOpen: () -> Void
    @State private var confirmingForget = false

    var body: some View {
        VStack(spacing: 22) {
            DeviceIllustration(deviceName: entry.name, size: 230)
                .frame(height: 250)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [deviceColor.color.opacity(entry.connected ? 0.34 : 0.12), .clear],
                                             center: .center, startRadius: 0, endRadius: 150))
                        .frame(width: 320, height: 320)
                )
                .opacity(entry.connected ? 1 : 0.6)
            VStack(spacing: 8) {
                Text(verbatim: entry.name).font(.system(size: 22, weight: .semibold))
                HStack(spacing: 8) {
                    PulseDot(active: entry.connected)
                    Text(entry.connected ? "Connected" : "Not connected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NTColor.secondary)
                }
            }
            HStack(spacing: 28) {
                if entry.connected {
                    IconActionButton(symbol: "arrow.right", title: active ? "Open" : "Use", prominent: true) {
                        model.useDevice(entry)
                        onOpen()
                    }
                } else {
                    IconActionButton(symbol: "link", title: "Connect", prominent: true) { model.connectDevice(entry) }
                }
                IconActionButton(symbol: "trash", title: "Forget", destructive: true) { confirmingForget = true }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .ntCard()
        .confirmationDialog("Forget this device?", isPresented: $confirmingForget) {
            Button("Forget", role: .destructive) { model.library.forget(entry) }
        } message: {
            Text("It is removed from the Mac's Bluetooth devices. You can pair it again later.")
        }
    }
}
