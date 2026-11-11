import XCTest
@testable import NothingX

final class EQResponseTests: XCTestCase {
    private func band(type: UInt8, gain: Float, freq: Float) -> EQBand {
        EQBand(id: 0, type: type, gain: gain, freq: freq, q: 1)
    }

    func testFlatBandsGiveZero() {
        XCTAssertEqual(EQResponse.db(at: 1000, bands: [band(type: 1, gain: 0, freq: 1000)]), 0, accuracy: 0.001)
    }

    func testPeakingReachesItsGainAtCentre() {
        XCTAssertEqual(EQResponse.db(at: 1000, bands: [band(type: 1, gain: 6, freq: 1000)]), 6, accuracy: 0.1)
    }

    func testShelvesApproachTheirGainAtTheEnds() {
        XCTAssertEqual(EQResponse.db(at: 20, bands: [band(type: 0, gain: 6, freq: 200)]), 6, accuracy: 0.3)
        XCTAssertEqual(EQResponse.db(at: 20000, bands: [band(type: 2, gain: -6, freq: 5000)]), -6, accuracy: 0.5)
    }
}
