import SwiftUI

struct NotificationsSection: View {
    private let service = NotificationService.shared

    private var stateLabel: String {
        switch service.authorization {
        case .allowed: String(localized: "Allowed")
        case .denied: String(localized: "Blocked")
        case .notDetermined: String(localized: "Not asked")
        case .unsupported: String(localized: "Unavailable")
        }
    }

    private func change(_ on: Bool, _ set: (Bool) -> Void) {
        set(on)
        if on, service.authorization == .notDetermined { Task { await service.requestAuthorization() } }
    }

    var body: some View {
        SettingsSection(title: "Notifications", trailing: stateLabel) {
            LazyVGrid(columns: settingsColumns, spacing: 12) {
                DeviceToggleTile(symbol: "bell.badge", title: "Headphone connected",
                                 detail: "When the headphone connects, not at launch.", value: service.connectedEnabled) {
                    change($0) { service.connectedEnabled = $0 }
                }
                DeviceToggleTile(symbol: "battery.25percent", title: "Low battery",
                                 detail: "Once per discharge, never while charging.", value: service.lowBatteryEnabled) {
                    change($0) { service.lowBatteryEnabled = $0 }
                }
            }
            SettingsTile(symbol: "gauge.with.dots.needle.33percent", title: "Alert at") {
                Segmented(options: LowBatteryRule.allowedThresholds.map { ($0, "\($0)%") },
                          selection: service.lowBatteryThreshold) { service.lowBatteryThreshold = $0 }
                    .disabled(!service.lowBatteryEnabled)
                    .opacity(service.lowBatteryEnabled ? 1 : 0.4)
            }
            permission
        }
        .task { await service.refreshAuthorization() }
    }

    @ViewBuilder private var permission: some View {
        switch service.authorization {
        case .notDetermined:
            ActionTile(symbol: "bell", title: "Notifications are not allowed yet.", detail: "",
                       buttonTitle: "Allow notifications") { Task { await service.requestAuthorization() } }
        case .denied:
            ActionTile(symbol: "bell.slash", title: "Notifications are blocked for Nothing X in System Settings.", detail: "",
                       buttonTitle: "Open System Settings") { service.openSystemSettings() }
        case .allowed, .unsupported:
            EmptyView()
        }
    }
}
