import Foundation

struct NowPlayingItem: Identifiable, Equatable {
    enum Source: String, CaseIterable {
        case spotify, music, youtube

        var name: String {
            switch self {
            case .spotify: "Spotify"
            case .music: "Music"
            case .youtube: "YouTube"
            }
        }

        var symbol: String {
            switch self {
            case .spotify: "waveform"
            case .music: "music.note"
            case .youtube: "play.rectangle.fill"
            }
        }
    }

    enum State { case playing, paused, unknown }
    enum Command { case playPause, next, previous }

    let source: Source
    var title: String
    var artist: String
    var state: State
    var artworkURL: URL?
    var viaMediaKeys = false
    var position: Double?
    var duration: Double?

    var id: String { source.rawValue }
    var canSeek: Bool { !viaMediaKeys && (duration ?? 0) > 0 }
}
