import XCTest
@testable import NothingX

final class BatteryReadingTests: XCTestCase {
    func testHeadphoneSingleEntry() {
        XCTAssertEqual(BatteryReading.decode([0x01, 0x06, 0x50]),
                       [BatteryReading(part: .headphone, level: 80, charging: false)])
    }

    func testEarbudsAndCase() {
        let readings = BatteryReading.decode([0x03, 0x02, 0x37, 0x03, 0x64, 0x04, 0xCB])
        XCTAssertEqual(readings.map(\.part), [.left, .right, .charger])
        XCTAssertEqual(readings.map(\.level), [55, 100, 75])
        XCTAssertEqual(readings.map(\.charging), [false, false, true])
    }

    func testTruncatedAndUnknownEntriesAreSkipped() {
        XCTAssertEqual(BatteryReading.decode([0x02, 0x09, 0x10, 0x02]), [])
        XCTAssertEqual(BatteryReading.decode([]), [])
    }
}
