import AppKit
import ApplicationServices

enum MediaTarget: CaseIterable {
    case spotify, music, chrome, safari, gecko

    var bundleID: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .music: "com.apple.Music"
        case .chrome: "com.google.Chrome"
        case .safari: "com.apple.Safari"
        case .gecko: "com.apple.systemevents"
        }
    }

    var name: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        case .chrome: "Chrome"
        case .safari: "Safari"
        case .gecko: "Zen, Firefox"
        }
    }

    var symbol: String {
        switch self {
        case .spotify: "waveform"
        case .music: "music.note"
        case .chrome, .safari: "globe"
        case .gecko: "flame"
        }
    }
}

enum MediaAccess { case granted, denied, notAsked, notRunning }

enum MediaPermissions {
    private static let denied = OSStatus(-1743)

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static func access(_ target: MediaTarget, ask: Bool = false) -> MediaAccess {
        if target == .gecko {
            guard accessibilityGranted else { return .notAsked }
        }
        guard isRunning(target.bundleID) else {
            if target == .gecko { launchSystemEvents() }
            return target == .gecko ? .notAsked : .notRunning
        }
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: target.bundleID)
        let status = AEDeterminePermissionToAutomateTarget(descriptor.aeDesc, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
        switch status {
        case noErr: return .granted
        case denied: return .denied
        default: return .notAsked
        }
    }

    static func request(_ target: MediaTarget) {
        if target == .gecko {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            ensureSystemEventsRunning()
        }
        _ = access(target, ask: true)
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func ensureSystemEventsRunning() {
        launchSystemEvents()
        for _ in 0..<20 where !isRunning("com.apple.systemevents") { Thread.sleep(forTimeInterval: 0.1) }
    }

    private static func launchSystemEvents() {
        guard !isRunning("com.apple.systemevents"),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systemevents") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
