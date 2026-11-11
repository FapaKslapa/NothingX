import AppKit

@MainActor
@Observable
final class NowPlayingService {
    private(set) var items: [NowPlayingItem] = []
    private(set) var musicArtwork: NSImage?
    var selected: NowPlayingItem.Source?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var viewers = 0
    @ObservationIgnored private var busy = false
    @ObservationIgnored private var artworkKey = ""
    @ObservationIgnored private let queue = DispatchQueue(label: "nothingx.nowplaying", qos: .utility)

    var current: NowPlayingItem? {
        items.first { $0.source == selected } ?? items.first { $0.state == .playing } ?? items.first
    }

    func attach() {
        viewers += 1
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func detach() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func canControl(_ item: NowPlayingItem) -> Bool {
        !item.viaMediaKeys || !items.contains { $0.source != item.source && $0.state == .playing }
    }

    func send(_ command: NowPlayingItem.Command) {
        guard let item = current else { return }
        let running = runningApps()
        queue.async { NowPlayingProviders.send(command, to: item, running: running) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.poll() }
    }

    private func runningApps() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    private func poll() {
        guard !busy else { return }
        busy = true
        let running = runningApps()
        let knownKey = artworkKey
        queue.async { [weak self] in
            let found = NowPlayingProviders.read(running: running)
            let music = found.first { $0.source == .music }
            let key = music.map { "\($0.title)|\($0.artist)" } ?? ""
            let image = (music != nil && key != knownKey) ? NowPlayingProviders.musicArtwork() : nil
            DispatchQueue.main.async {
                self?.apply(found, artwork: image, key: key)
            }
        }
    }

    private func apply(_ found: [NowPlayingItem], artwork: NSImage?, key: String) {
        busy = false
        if found != items { items = found }
        if key != artworkKey {
            artworkKey = key
            musicArtwork = artwork
        }
    }
}
