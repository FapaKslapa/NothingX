import XCTest
@testable import NothingX

final class GestureBindingTests: XCTestCase {
    private let earTable: [UInt8] = [
        0x08, 0x02, 0x01, 0x02, 0x09, 0x03, 0x01, 0x02, 0x09, 0x02, 0x01, 0x03, 0x08, 0x03, 0x01, 0x03, 0x08,
        0x02, 0x01, 0x07, 0x16, 0x03, 0x01, 0x07, 0x16, 0x02, 0x01, 0x09, 0x01, 0x03, 0x01, 0x09, 0x01,
    ]

    func testEarbudRowsKeepBothSidesDistinct() {
        let rows = GestureBinding.decodeTable(earTable)
        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(Set(rows.map(\.id)).count, 8)
    }

    func testSideNamesOnlyForEarbuds() {
        XCTAssertNotNil(GestureBinding.sideName(2))
        XCTAssertNotNil(GestureBinding.sideName(3))
        XCTAssertNil(GestureBinding.sideName(6))
    }

    func testDeviceKindFromName() {
        XCTAssertEqual(DeviceKind(name: "Nothing Headphone (a)"), .headphone)
        XCTAssertEqual(DeviceKind(name: "Nothing Ear (a)"), .earbuds)
    }
}
