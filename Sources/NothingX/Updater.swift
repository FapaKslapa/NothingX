import Foundation
import Observation
import Sparkle

@MainActor @Observable
final class Updater {
    static let shared = Updater()

    private(set) var canCheckForUpdates = false

    var automaticallyChecks: Bool {
        get { automaticChecksValue }
        set {
            guard isAvailable else { return }
            controller.updater.automaticallyChecksForUpdates = newValue
            automaticChecksValue = newValue
        }
    }
    private var automaticChecksValue = false

    let currentVersion: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "—"
        if let build = info["CFBundleVersion"] as? String { return "\(short) (\(build))" }
        return short
    }()

    let isAvailable: Bool

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    private init() {
        let bundled = Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        isAvailable = bundled
        controller = SPUStandardUpdaterController(startingUpdater: bundled, updaterDelegate: nil, userDriverDelegate: nil)
        guard bundled else { return }
        let updater = controller.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticChecksValue = updater.automaticallyChecksForUpdates

        observations.append(updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            MainActor.assumeIsolated { self?.canCheckForUpdates = value }
        })
        observations.append(updater.observe(\.automaticallyChecksForUpdates, options: [.new]) { [weak self] updater, _ in
            let value = updater.automaticallyChecksForUpdates
            MainActor.assumeIsolated { self?.automaticChecksValue = value }
        })
    }

    func checkForUpdates() {
        guard isAvailable else { return }
        controller.checkForUpdates(nil)
    }
}
