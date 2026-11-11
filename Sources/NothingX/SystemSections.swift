import SwiftUI

struct WiredSection: View {
    private let controller = WiredOutputController.shared

    var body: some View {
        SettingsSection(title: "Wired mode") {
            DeviceToggleTile(symbol: "cable.connector", title: "Use as the Mac’s output",
                             detail: "When plugged in by USB, make the headphone the sound output, then give the previous output back when unplugged. Off leaves your output choice alone.",
                             value: controller.enabled) { controller.enabled = $0 }
        }
    }
}

struct UpdatesSection: View {
    private let updater = Updater.shared

    var body: some View {
        SettingsSection(title: "Updates") {
            LazyVGrid(columns: settingsColumns, spacing: 12) {
                DeviceToggleTile(symbol: "arrow.triangle.2.circlepath", title: "Check automatically",
                                 detail: updater.isAvailable ? "" : "Unavailable in development builds",
                                 value: updater.isAvailable ? updater.automaticallyChecks : nil) { updater.automaticallyChecks = $0 }
                    .disabled(!updater.isAvailable)
                ActionTile(symbol: "arrow.down.circle", title: "Version", detail: LocalizedStringKey(updater.currentVersion),
                           buttonTitle: "Check now") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}

struct WelcomeSection: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        SettingsSection(title: "Welcome") {
            ActionTile(symbol: "sparkles", title: "First-launch tour", detail: "Replay it any time.",
                       buttonTitle: "Show") { OnboardingController.shared.replay { openWindow(id: "main") } }
        }
    }
}
