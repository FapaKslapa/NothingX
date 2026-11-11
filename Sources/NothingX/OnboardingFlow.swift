import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome, bluetooth, connect, notifications, media, macAnchor, done
}

struct OnboardingFlow: Equatable {

    static let version = 3

    enum Bluetooth: Equatable {

        case notAsked

        case waiting
        case denied
        case allowed
    }

    enum Outcome: Equatable { case completed, skipped }

    enum Event: Equatable {
        case next
        case skip
        case allowBluetooth
        case bluetoothChanged(Bluetooth)
    }

    private(set) var step: OnboardingStep = .welcome
    private(set) var bluetooth: Bluetooth
    private(set) var outcome: Outcome?

    init(bluetooth: Bluetooth) {
        self.bluetooth = bluetooth
    }

    var autoAdvances: Bool { outcome == nil && step == .bluetooth && bluetooth == .allowed }

    var linkShouldRun: Bool {
        outcome != nil || step.rawValue > OnboardingStep.bluetooth.rawValue
            || (step == .bluetooth && bluetooth != .notAsked)
    }

    var completedSteps: Set<OnboardingStep> {
        if outcome == .completed { return Set(OnboardingStep.allCases) }
        return Set(OnboardingStep.allCases.filter { $0.rawValue < step.rawValue })
    }

    static func shouldPresent(completed: Bool, completedVersion: Int) -> Bool {
        !(completed && completedVersion >= version)
    }

    mutating func handle(_ event: Event) {
        guard outcome == nil else { return }
        switch event {
        case .skip:
            outcome = .skipped
        case .next:
            switch step {
            case .welcome:

                step = bluetooth == .allowed ? .connect : .bluetooth
            case .bluetooth:
                if bluetooth == .allowed { step = .connect }
            case .connect:
                step = .notifications
            case .notifications:
                step = .media
            case .media:
                step = .macAnchor
            case .macAnchor:
                step = .done
            case .done:
                outcome = .completed
            }
        case .allowBluetooth:
            if step == .bluetooth, bluetooth == .notAsked { bluetooth = .waiting }
        case .bluetoothChanged(let state):
            bluetooth = state

            if step == .connect, state != .allowed { step = .bluetooth }
        }
    }
}
