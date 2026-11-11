import AppKit
import SwiftUI

extension OnboardingStep {
    var label: String {
        switch self {
        case .welcome: String(localized: "Welcome")
        case .bluetooth: String(localized: "Bluetooth")
        case .connect: String(localized: "Headphone")
        case .notifications: String(localized: "Notifications")
        case .media: String(localized: "Media")
        case .macAnchor: String(localized: "Spatial audio")
        case .done: String(localized: "Ready")
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .connect: "headphones"
        case .notifications: "bell.badge"
        case .media: "music.note"
        case .macAnchor: "person.wave.2"
        case .done: "checkmark"
        }
    }
}

enum OnboardingLinks {
    static func openBluetoothPairing() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings"),
           NSWorkspace.shared.open(url) { return }
        BluetoothGate.openSettings()
    }
}

struct OnboardingPage<Content: View>: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let message { OnboardingBody(message) }
            content
        }
        .frame(maxWidth: 560, alignment: .leading)
    }
}

struct OnboardingBody: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(NTColor.secondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct WelcomeStep: View {
    var body: some View {
        OnboardingPage(title: "Your Nothing audio, from the Mac.",
                       message: "Nothing X controls Nothing headphones and earbuds from macOS: battery, noise control, equalizer, gestures and more.") {
            Text("Unofficial. Not affiliated with Nothing Technology Limited.").ntLabel(NTColor.disabled)
        }
    }
}

struct BluetoothStep: View {
    let state: OnboardingFlow.Bluetooth

    var body: some View {
        OnboardingPage(title: "Bluetooth access",
                       message: "The app needs Bluetooth to reach the headphone. macOS asks once.") {
            VStack(alignment: .leading, spacing: 8) {
                switch state {
                case .notAsked:
                    EmptyView()
                case .waiting:
                    Text("Waiting for Bluetooth permission…").ntLabel(NTColor.primary)
                    Text("Answer the macOS prompt. It may be on another display.").ntLabel(NTColor.disabled)
                case .denied:
                    Text("Bluetooth access denied").ntLabel(NTColor.primary)
                    Text("Allow it in Privacy & Security › Bluetooth.").ntLabel(NTColor.disabled)
                    Text("The tour continues as soon as access is allowed.").ntLabel(NTColor.disabled)
                case .allowed:
                    Text("Bluetooth access allowed").ntLabel(NTColor.display)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConnectStep: View {
    @Environment(HeadphoneModel.self) private var model

    private var connected: Bool { model.connection == .connected }

    var body: some View {
        OnboardingPage(title: "Connect the headphone") {
            if connected {
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: model.deviceName).font(.system(size: 17, weight: .medium))
                    BatteryGauge(readings: model.batteryParts)
                    OnboardingBody("Connected. Battery, noise control and the rest are live.")
                }
                .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingBody(model.isWired
                        ? "The headphone is plugged in by USB, which turns Bluetooth off. Unplug the cable to connect, or skip for now."
                        : "Switch the headphone on. If it is not paired with this Mac yet, hold its pairing button until the light blinks, then pair it in System Settings › Bluetooth.")
                    HStack(spacing: 8) {
                        PulseDot(active: false)
                        (model.isWired ? Text("Wired (USB)")
                            : model.connection == .connecting ? Text("Connecting…") : Text("Searching for headphone"))
                            .ntLabel(NTColor.disabled)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: connected)
    }
}

struct NotificationsStep: View {
    private let service = NotificationService.shared

    var body: some View {
        OnboardingPage(title: "Notifications",
                       message: "Two optional alerts, delivered by macOS. Change them any time in Settings.") {
            HStack(alignment: .top, spacing: 12) {
                DeviceToggleTile(symbol: "battery.25percent", title: "Low battery",
                                 detail: "Once per discharge, never while charging.", value: service.lowBatteryEnabled) {
                    service.lowBatteryEnabled = $0
                }
                DeviceToggleTile(symbol: "bell.badge", title: "Headphone connected",
                                 detail: "When the headphone connects, not at launch.", value: service.connectedEnabled) {
                    service.connectedEnabled = $0
                }
            }
            permissionState
        }
        .task { await service.refreshAuthorization() }
    }

    @ViewBuilder private var permissionState: some View {
        switch service.authorization {
        case .allowed:
            Text("Allowed").ntLabel(NTColor.display)
        case .denied:
            Text("Notifications are blocked for Nothing X in System Settings.").ntLabel(NTColor.secondary)
        case .unsupported:
            Text("Notifications need the packaged app.").ntLabel(NTColor.secondary)
        case .notDetermined:
            EmptyView()
        }
    }
}

struct MediaStep: View {
    var body: some View {
        OnboardingPage(title: "Control your music from the app.",
                       message: "Nothing X can show and control Spotify, Music and YouTube. macOS asks for permission once per app. You can also do this later in Settings.") {
            MediaPermissionList()
        }
    }
}

struct MacAnchorStep: View {
    var body: some View {
        OnboardingPage(title: "Sound that stays in front of you.",
                       message: "Under Spatial audio, Fixed to Mac makes what the Mac plays stay in front of you, and follows your head with the headphone’s motion sensor.") {
            Text("The first time you switch it on, macOS asks to allow System Audio Recording. Nothing is captured before that.")
                .ntLabel(NTColor.disabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DoneStep: View {
    var body: some View {
        OnboardingPage(title: "You're all set.") {
            VStack(spacing: 12) {
                SettingsTile(symbol: "menubar.rectangle", title: "Menu bar", detail: "Battery and noise control, always at hand.") { EmptyView() }
                SettingsTile(symbol: "music.note", title: "Now playing", detail: "Spotify, Music and YouTube, with cover art and controls.") { EmptyView() }
                SettingsTile(symbol: "rectangle.stack", title: "Your devices", detail: "Connect, switch or forget a device any time.") { EmptyView() }
            }
        }
    }
}

struct OnboardingProgress: View {
    let step: OnboardingStep
    let completed: Set<OnboardingStep>

    private var number: Int { step.rawValue + 1 }
    private var total: Int { OnboardingStep.allCases.count }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(completed.contains(s) || s == step ? NTColor.display : Color.white.opacity(0.18))
                    .frame(width: s == step ? 28 : 8, height: 8)
                    .animation(.snappy(duration: 0.25), value: step)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "Step %d of %d: %@"), number, total, step.label))
    }
}
