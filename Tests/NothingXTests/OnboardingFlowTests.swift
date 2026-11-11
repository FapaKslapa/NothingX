import XCTest
@testable import NothingX

final class OnboardingFlowTests: XCTestCase {

    private func flow(at step: OnboardingStep) -> OnboardingFlow {
        if step == .bluetooth {
            var f = OnboardingFlow(bluetooth: .notAsked)
            f.handle(.next)
            return f
        }
        var f = OnboardingFlow(bluetooth: .allowed)
        while f.step != step {
            f.handle(.next)
            if f.outcome != nil { XCTFail("ran past \(step)"); break }
        }
        return f
    }

    func testFirstLaunchPath() {
        var f = OnboardingFlow(bluetooth: .notAsked)
        XCTAssertEqual(f.step, .welcome)
        f.handle(.next)
        XCTAssertEqual(f.step, .bluetooth)
        XCTAssertFalse(f.autoAdvances)
        f.handle(.allowBluetooth)
        XCTAssertEqual(f.bluetooth, .waiting)
        XCTAssertFalse(f.autoAdvances)
        f.handle(.bluetoothChanged(.allowed))
        XCTAssertTrue(f.autoAdvances)
        f.handle(.next)
        XCTAssertEqual(f.step, .connect)
        XCTAssertFalse(f.autoAdvances)
        f.handle(.next)
        XCTAssertEqual(f.step, .notifications)
        f.handle(.next)
        XCTAssertEqual(f.step, .media)
        f.handle(.next)
        XCTAssertEqual(f.step, .macAnchor)
        f.handle(.next)
        XCTAssertEqual(f.step, .done)
        XCTAssertNil(f.outcome)
        XCTAssertEqual(f.completedSteps, [.welcome, .bluetooth, .connect, .notifications, .media, .macAnchor])
        f.handle(.next)
        XCTAssertEqual(f.outcome, .completed)
        XCTAssertEqual(f.completedSteps, Set(OnboardingStep.allCases))
    }

    func testAlreadyAllowedSkipsBluetoothStep() {
        var f = OnboardingFlow(bluetooth: .allowed)
        XCTAssertTrue(f.completedSteps.isEmpty)
        f.handle(.next)
        XCTAssertEqual(f.step, .connect)
        XCTAssertTrue(f.completedSteps.contains(.bluetooth))
        XCTAssertTrue(f.completedSteps.contains(.welcome))
        XCTAssertFalse(f.completedSteps.contains(.connect))
    }

    func testNextOnBluetoothIgnoredWhileWaitingOrDenied() {
        for state in [OnboardingFlow.Bluetooth.waiting, .denied] {
            var f = OnboardingFlow(bluetooth: .notAsked)
            f.handle(.next)
            f.handle(.bluetoothChanged(state))
            f.handle(.next)
            XCTAssertEqual(f.step, .bluetooth, "\(state)")
            XCTAssertFalse(f.autoAdvances)
        }
        var f = OnboardingFlow(bluetooth: .notAsked)
        f.handle(.next)
        f.handle(.next)
        XCTAssertEqual(f.step, .bluetooth, "notAsked")
    }

    func testAllowBluetoothOnlyFromNotAskedOnBluetoothStep() {
        var f = OnboardingFlow(bluetooth: .notAsked)
        f.handle(.allowBluetooth)
        XCTAssertEqual(f.bluetooth, .notAsked)
        f.handle(.next)
        f.handle(.bluetoothChanged(.denied))
        f.handle(.allowBluetooth)
        XCTAssertEqual(f.bluetooth, .denied)
    }

    func testDeniedAtConnectRegressesThenAutoAdvancesAgain() {
        var f = flow(at: .connect)
        f.handle(.bluetoothChanged(.denied))
        XCTAssertEqual(f.step, .bluetooth)
        XCTAssertEqual(f.bluetooth, .denied)
        XCTAssertFalse(f.autoAdvances)
        f.handle(.bluetoothChanged(.allowed))
        XCTAssertTrue(f.autoAdvances)
        f.handle(.next)
        XCTAssertEqual(f.step, .connect)
    }

    func testWaitingOrNotAskedAtConnectAlsoRegress() {
        for state in [OnboardingFlow.Bluetooth.waiting, .notAsked] {
            var f = flow(at: .connect)
            f.handle(.bluetoothChanged(state))
            XCTAssertEqual(f.step, .bluetooth, "\(state)")
        }
        var f = flow(at: .connect)
        f.handle(.bluetoothChanged(.allowed))
        XCTAssertEqual(f.step, .connect)
    }

    func testBluetoothChangesIgnoredAfterConnect() {
        for step in [OnboardingStep.notifications, .media, .macAnchor, .done] {
            var f = flow(at: step)
            for state in [OnboardingFlow.Bluetooth.denied, .waiting, .notAsked, .allowed] {
                f.handle(.bluetoothChanged(state))
                XCTAssertEqual(f.step, step, "\(state)")
                XCTAssertEqual(f.bluetooth, state)
                XCTAssertFalse(f.autoAdvances)
            }
        }
    }

    func testSkipFromEveryStepEndsTheFlow() {
        for step in OnboardingStep.allCases {
            var f = flow(at: step)
            f.handle(.skip)
            XCTAssertEqual(f.outcome, .skipped, "\(step)")
            let frozen = f
            for event in [OnboardingFlow.Event.next, .skip, .allowBluetooth, .bluetoothChanged(.denied)] {
                f.handle(event)
            }
            XCTAssertEqual(f, frozen, "\(step)")
            XCTAssertFalse(f.autoAdvances)
        }
    }

    func testEventsAfterCompletionAreIgnored() {
        var f = flow(at: .done)
        f.handle(.next)
        XCTAssertEqual(f.outcome, .completed)
        f.handle(.skip)
        XCTAssertEqual(f.outcome, .completed)
    }

    func testLinkShouldRun() {
        for state in [OnboardingFlow.Bluetooth.notAsked, .waiting, .denied, .allowed] {
            XCTAssertFalse(OnboardingFlow(bluetooth: state).linkShouldRun, "welcome \(state)")
        }

        var f = OnboardingFlow(bluetooth: .notAsked)
        f.handle(.next)
        XCTAssertEqual(f.step, .bluetooth)
        XCTAssertFalse(f.linkShouldRun)
        f.handle(.allowBluetooth)
        XCTAssertTrue(f.linkShouldRun)

        var denied = OnboardingFlow(bluetooth: .denied)
        denied.handle(.next)
        XCTAssertEqual(denied.step, .bluetooth)
        XCTAssertTrue(denied.linkShouldRun)

        var allowed = OnboardingFlow(bluetooth: .notAsked)
        allowed.handle(.next)
        allowed.handle(.bluetoothChanged(.allowed))
        XCTAssertTrue(allowed.linkShouldRun)

        for step in [OnboardingStep.connect, .notifications, .media, .macAnchor, .done] {
            XCTAssertTrue(flow(at: step).linkShouldRun, "\(step)")
        }

        var skipped = OnboardingFlow(bluetooth: .notAsked)
        skipped.handle(.skip)
        XCTAssertTrue(skipped.linkShouldRun)
    }

    func testShouldPresent() {
        XCTAssertTrue(OnboardingFlow.shouldPresent(completed: false, completedVersion: 0))
        XCTAssertTrue(OnboardingFlow.shouldPresent(completed: true, completedVersion: 1))
        XCTAssertTrue(OnboardingFlow.shouldPresent(completed: true, completedVersion: 0))
        XCTAssertTrue(OnboardingFlow.shouldPresent(completed: true, completedVersion: 2))
        XCTAssertFalse(OnboardingFlow.shouldPresent(completed: true, completedVersion: 3))
    }

    func testSteps() {
        XCTAssertEqual(OnboardingStep.allCases.count, 7)
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .bluetooth, .connect, .notifications, .media, .macAnchor, .done])
        XCTAssertEqual(OnboardingStep.allCases.map(\.rawValue), Array(0..<7))
    }
}
