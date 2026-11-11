import XCTest
@testable import NothingX

final class WiredModeTests: XCTestCase {

    func testMatchesNothingHeadphone() {
        XCTAssertTrue(USBHeadphoneMatch.matches(vendorID: 0xBE58, productName: "Nothing Headphone (1)"))
        XCTAssertTrue(USBHeadphoneMatch.matches(vendorID: 48728, productName: "nothing headphone (2)"))
    }

    func testRejectsOtherVendorsAndProducts() {
        XCTAssertFalse(USBHeadphoneMatch.matches(vendorID: 0x05AC, productName: "Nothing Headphone (1)"))
        XCTAssertFalse(USBHeadphoneMatch.matches(vendorID: 0xBE58, productName: "Nothing Ear (a) Charging Case"))
        XCTAssertFalse(USBHeadphoneMatch.matches(vendorID: 0xBE58, productName: nil))
        XCTAssertFalse(USBHeadphoneMatch.matches(vendorID: 0xBE58, productName: ""))
    }

    func testTrackerAttachAndDetach() {
        var t = USBPresenceTracker()
        XCTAssertFalse(t.isPresent)
        t.attach(id: 7, productName: "Nothing Headphone (1)", serial: "M1")
        XCTAssertTrue(t.isPresent)
        XCTAssertEqual(t.current?.serial, "M1")
        XCTAssertFalse(t.detach(id: 99), "an unknown id is not a removal")
        XCTAssertTrue(t.isPresent)
        XCTAssertTrue(t.detach(id: 7))
        XCTAssertFalse(t.isPresent)
        XCTAssertNil(t.current)
    }

    func testTrackerKeepsOtherDeviceWhenOneLeaves() {
        var t = USBPresenceTracker()
        t.attach(id: 1, productName: "Nothing Headphone (1)", serial: "A")
        t.attach(id: 2, productName: "Nothing Headphone (1)", serial: "B")
        XCTAssertEqual(t.current?.serial, "B")
        t.detach(id: 2)
        XCTAssertTrue(t.isPresent)
        XCTAssertEqual(t.current?.serial, "A")
    }

    func testTrackerReattachIsIdempotent() {
        var t = USBPresenceTracker()
        t.attach(id: 1, productName: "Nothing Headphone (1)", serial: nil)
        t.attach(id: 1, productName: "Nothing Headphone (1)", serial: nil)
        XCTAssertTrue(t.detach(id: 1))
        XCTAssertFalse(t.isPresent)
    }

    private let speakers = "BuiltInSpeakers"
    private let usb = "NothingUSB"

    func testSwitchesOnPlugAndRestoresOnUnplug() {
        var p = WiredOutputPolicy()
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .switchTo(uid: usb))

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: usb), .none)

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: "Display"), .restore(uid: speakers))
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: speakers), .none)
    }

    func testNoRestoreWhenMacOSAlreadyFellBackToThePreviousOutput() {
        var p = WiredOutputPolicy()
        _ = p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: speakers), .none)
    }

    func testDisabledNeverSwitches() {
        var p = WiredOutputPolicy()
        XCTAssertEqual(p.evaluate(enabled: false, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .none)
        XCTAssertEqual(p.evaluate(enabled: false, usbPresent: false, headphoneUID: nil, defaultUID: speakers), .none)
    }

    func testWaitsForCoreAudioToListTheDevice() {
        var p = WiredOutputPolicy()

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: nil, defaultUID: speakers), .none)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .switchTo(uid: usb))
    }

    func testUserChoiceWhilePluggedIsNotFoughtOrRestored() {
        var p = WiredOutputPolicy()
        _ = p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers)

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: "AirPlay"), .none)

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: "AirPlay"), .none)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: "AirPlay"), .none)

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: "AirPlay"), .switchTo(uid: usb))
    }

    func testMacOSFallbackAtUnplugIsNotMistakenForAUserChoice() {
        var p = WiredOutputPolicy()
        _ = p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers)

        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: nil, defaultUID: "Display"), .none)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: "Display"), .restore(uid: speakers))
    }

    func testTurningTheSettingOffRestoresImmediately() {
        var p = WiredOutputPolicy()
        _ = p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers)
        XCTAssertEqual(p.evaluate(enabled: false, usbPresent: true, headphoneUID: usb, defaultUID: usb), .restore(uid: speakers))
        XCTAssertEqual(p.evaluate(enabled: false, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .none)
    }

    func testTurningTheSettingOnWhileAlreadyPlugged() {
        var p = WiredOutputPolicy()
        XCTAssertEqual(p.evaluate(enabled: false, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .none)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .switchTo(uid: usb))
    }

    func testAlreadyTheDefaultMeansNothingToRemember() {
        var p = WiredOutputPolicy()
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: usb), .none)
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: false, headphoneUID: nil, defaultUID: speakers), .none)
    }

    func testFailedSwitchIsRetried() {
        var p = WiredOutputPolicy()
        _ = p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers)
        p.switchFailed()
        XCTAssertEqual(p.evaluate(enabled: true, usbPresent: true, headphoneUID: usb, defaultUID: speakers), .switchTo(uid: usb))
    }

    @MainActor
    func testIsWiredIsFalseWithoutMonitor() {
        let model = HeadphoneModel(startLink: false, startUSBMonitor: false)
        XCTAssertFalse(model.usbPresent)
        XCTAssertFalse(model.isWired)
    }
}
