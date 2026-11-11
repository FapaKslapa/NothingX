import XCTest
@testable import NothingX

final class NowPlayingTests: XCTestCase {
    func testVideoIDIsReadFromTheWatchURL() {
        XCTAssertEqual(NowPlayingProviders.videoID("https://www.youtube.com/watch?v=abc123&t=9s"), "abc123")
        XCTAssertNil(NowPlayingProviders.videoID("https://www.youtube.com/feed/subscriptions"))
    }

    func testYouTubeTitleIsTheWindowTitleBeforeTheSiteName() {
        let titles = ["164 tab", "Nel cuore della notte - YouTube — Zen Browser"]
        XCTAssertEqual(NowPlayingProviders.youtubeTitle(in: titles), "Nel cuore della notte")
        XCTAssertNil(NowPlayingProviders.youtubeTitle(in: ["Inbox", "Docs"]))
    }

    func testOnlyNothingAudioDevicesAreListed() {
        XCTAssertTrue(DeviceKind.isNothingAudio("Nothing Headphone (a)"))
        XCTAssertTrue(DeviceKind.isNothingAudio("Nothing Ear (a)"))
        XCTAssertFalse(DeviceKind.isNothingAudio("Nothing Phone (3)"))
        XCTAssertFalse(DeviceKind.isNothingAudio("Magic Mouse"))
    }

    @MainActor func testGeckoControlsStepAsideWhileAnotherSourceIsPlaying() {
        let service = NowPlayingService()
        let youtube = NowPlayingItem(source: .youtube, title: "t", artist: "a", state: .unknown, viaMediaKeys: true)
        XCTAssertTrue(service.canControl(youtube))
    }

    func testYouTubeProbeCarriesStateAndPosition() {
        let probe = NowPlayingProviders.parseProbe("playing,83,240")
        XCTAssertEqual(probe.state, .playing)
        XCTAssertEqual(probe.position, 83)
        XCTAssertEqual(probe.duration, 240)
        XCTAssertEqual(NowPlayingProviders.parseProbe("unknown").position, nil)
    }

    func testProgressTimeFormat() {
        XCTAssertEqual(ProgressSlider.format(75), "1:15")
        XCTAssertEqual(ProgressSlider.format(-3), "0:00")
    }
}
