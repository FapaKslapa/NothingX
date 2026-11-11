import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class OnboardingController {
    static let shared = OnboardingController()

    private(set) var isPresented: Bool

    enum Key {
        static let completed = "onboarding.completed"
        static let version = "onboarding.version"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        isPresented = OnboardingFlow.shouldPresent(completed: defaults.bool(forKey: Key.completed),
                                                   completedVersion: defaults.integer(forKey: Key.version))
    }

    func present() { isPresented = true }

    func finish(_ outcome: OnboardingFlow.Outcome) {
        defaults.set(true, forKey: Key.completed)
        defaults.set(OnboardingFlow.version, forKey: Key.version)
        isPresented = false
    }

    func replay(openWindow: () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
            $0.title == "Nothing X" && $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized)
        }) {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow()
        }
        present()
    }
}
